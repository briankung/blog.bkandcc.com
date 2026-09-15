PORT := "1112"
PIDFILE := ".zola-serve.pid"
SRC_SITE := env("BRIANKUNG_DEV", "~/Code/briankung.dev")

default:
    @just --list

build:
    zola build

serve:
    @if [ -f {{PIDFILE}} ] && kill -0 $(cat {{PIDFILE}}) 2>/dev/null; then \
        echo "Already running on :{{PORT}} (pid $(cat {{PIDFILE}}))"; \
    else \
        nohup zola serve --interface 127.0.0.1 --port {{PORT}} > .zola-serve.log 2>&1 & \
        echo $! > {{PIDFILE}}; \
        echo "Started Zola on http://127.0.0.1:{{PORT}} (pid $(cat {{PIDFILE}}))"; \
    fi

stop:
    @if [ -f {{PIDFILE}} ] && kill -0 $(cat {{PIDFILE}}) 2>/dev/null; then \
        kill $(cat {{PIDFILE}}) && rm -f {{PIDFILE}}; \
        echo "Stopped Zola"; \
    else \
        rm -f {{PIDFILE}}; \
        echo "Not running"; \
    fi

serve-drafts:
    zola serve --drafts --interface 127.0.0.1 --port {{PORT}}

check:
    zola check

clean:
    rm -rf public

# Scaffold a new draft: just new "My Great Post"
new title:
    #!/usr/bin/env bash
    set -euo pipefail
    slug=$(echo "{{title}}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
    today=$(date -u +%Y-%m-%d)
    iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    file="content/${today}-${slug}.md"
    if [ -e "$file" ]; then echo "exists: $file"; exit 1; fi
    cat > "$file" <<EOF
    +++
    title = "{{title}}"
    date = ${iso}
    draft = true
    path = "/drafts/${today}-${slug}/"
    slug = "${slug}"
    [taxonomies]
    categories = []
    tags = []
    +++

    EOF
    echo "Created $file (draft)"
    echo "Publish with: just publish ${slug}"

# List unpublished drafts in content/ (valid targets for `just publish`)
drafts:
    @grep -l '^draft = true' content/*.md 2>/dev/null || echo "(no drafts)"

# Publish a draft; `target` = any unique substring of a draft filename in content/ (see `just drafts`)
publish target:
    #!/usr/bin/env bash
    set -euo pipefail
    matches=( $(ls content/*"{{target}}"*.md 2>/dev/null) )
    if [ "${#matches[@]}" -eq 0 ]; then
        echo "no draft matching '{{target}}' in content/ (run 'just drafts' to list them)"
        exit 1
    fi
    if [ "${#matches[@]}" -gt 1 ]; then echo "multiple matches; be more specific:"; printf '  %s\n' "${matches[@]}"; exit 1; fi
    old="${matches[0]}"
    if ! grep -q '^draft = true' "$old"; then echo "$old is not a draft"; exit 1; fi
    slug=$(basename "$old" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
    today=$(date -u +%Y-%m-%d)
    iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    new="content/${today}-${slug}.md"
    if [ "$old" != "$new" ] && [ -e "$new" ]; then echo "destination exists: $new"; exit 1; fi
    awk -v iso="$iso" -v slug="$slug" -v today_slash="$(echo "$today" | tr - /)" '
        /^draft = true$/ { next }
        /^date = / { print "date = " iso; next }
        /^path = / { print "path = \"/" today_slash "/" slug "/\""; next }
        { print }
    ' "$old" > "$old.tmp" && mv "$old.tmp" "$old"
    if [ "$old" != "$new" ]; then mv "$old" "$new"; fi
    echo "Published $new"

# Copies the .md (same path/date, so old URLs survive) and its /assets/images/ out
# of briankung.dev (git rm there) and appends a 301 to its static/_redirects.
# Review both repos' diffs, then commit each. Override the source with $BRIANKUNG_DEV.
# Move a post here from briankung.dev: just import public-school-is-a-bad-deal
import target:
    #!/usr/bin/env bash
    set -euo pipefail
    src=$(eval echo {{SRC_SITE}})
    matches=( $(ls "$src"/content/*"{{target}}"*.md 2>/dev/null) )
    if [ "${#matches[@]}" -eq 0 ]; then echo "no post matching '{{target}}' in $src/content/"; exit 1; fi
    if [ "${#matches[@]}" -gt 1 ]; then echo "multiple matches; be more specific:"; printf '  %s\n' "${matches[@]}"; exit 1; fi
    post="${matches[0]}"
    name=$(basename "$post")
    if [ -e "content/$name" ]; then echo "already imported: content/$name"; exit 1; fi
    path=$(sed -nE 's/^path = "([^"]+)"/\1/p' "$post" | head -1)
    cp "$post" "content/$name"
    git -C "$src" rm -q "content/$name"
    cover=$(sed -nE 's/^cover_image = "([^"]+)"/\/assets\/images\/\1/p' "content/$name")
    for img in $( { grep -oE '/assets/images/[^) "]+' "content/$name"; echo "$cover"; } | grep . | sort -u); do
        if [ -f "$src/static$img" ]; then
            mkdir -p "static/$(dirname "$img")"
            cp "$src/static$img" "static$img"
            git -C "$src" rm -q "static$img"
            echo "  image: $img"
        else
            echo "  WARNING: missing image $src/static$img"
        fi
    done
    if [ -n "$path" ]; then
        printf '%s https://blog.bkandcc.com%s 301\n' "$path" "$path" >> "$src/static/_redirects"
        echo "  redirect: $path -> https://blog.bkandcc.com$path"
    fi
    echo "Imported content/$name. Now review + commit here and in $src."

# Push main → Cloudflare Pages build & deploy
deploy:
    @branch=$(git rev-parse --abbrev-ref HEAD); \
    if [ "$branch" != "main" ]; then \
        echo "Not on main (on $branch). Merge or check out main first."; \
        exit 1; \
    fi
    git push origin main
    @echo "Pushed. Watch build at https://dash.cloudflare.com/?to=/:account/pages"

open-site:
    open https://blog.bkandcc.com

open-dash:
    open "https://dash.cloudflare.com/?to=/:account/pages"
