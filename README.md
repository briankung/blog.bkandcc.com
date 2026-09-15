# blog.bkandcc.com

Household blog built with [Zola](https://www.getzola.org/). Sibling of
[briankung.dev](https://github.com/briankung/briankung.dev), which keeps the
programming writing; personal posts are moving here (see `just import`).

## Local development

```bash
just serve         # http://127.0.0.1:1112 (background, see .zola-serve.log)
just serve-drafts  # same, but surfaces all drafts
just stop
just build         # one-shot build into public/
just check         # broken-link checker
just clean         # rm -rf public/
```

Requires `zola` (≥ 0.22) and `just`. Install with `brew install zola just`.
Port 1112 so it can run alongside briankung.dev on 1111.

### Authoring

```bash
just new "My Great Post"        # scaffolds a draft from the title
just drafts                     # list drafts
just publish my-great-post      # promotes the draft → published, dated today
```

`just new` always starts a draft (`draft = true`). It slugifies the title, writes today's UTC date into the frontmatter, and creates `content/YYYY-MM-DD-<slug>.md`. Preview with `just serve-drafts`.

`just publish <slug>` matches any draft in `content/` whose filename contains the argument, rewrites the date + `path` to today, drops `draft = true`, and renames the file.

### Moving a post over from briankung.dev

```bash
just import public-school-is-a-bad-deal
```

Matches a post in `~/Code/briankung.dev/content/` (override with `BRIANKUNG_DEV=/path`), then:

1. copies the `.md` here unchanged, so it keeps its date, slug and `path` (`/YYYY/MM/DD/slug/`) and the URL only changes host;
2. copies every `/assets/images/...` the post references into `static/`;
3. `git rm`s both from briankung.dev;
4. appends `<path> https://blog.bkandcc.com<path> 301` to briankung.dev's `static/_redirects` (Cloudflare Pages reads that file), so old links keep working.

Nothing is committed. Review both repos' diffs, then commit and deploy each.

## Repo layout

```
config.toml          site config (taxonomies, syntax highlighting, link checker)
content/             posts as flat .md files; drafts marked `draft = true`
content/pages/       about (kept out of the date-sorted root paginator)
templates/           Tera templates (base, index, page, section, taxonomy_*, 404)
templates/partials/  head, header, footer, post-meta
sass/                main.scss + _base/_layout/_post partials
static/              CNAME + assets/images/ (served as /assets/images/...)
```

## Deployment — Cloudflare Pages

The site builds on every push to `main` via Cloudflare Pages.

**One-time setup** (mirrors briankung.dev; done 2026-09-14 via the Cloudflare API, recorded here for reference). Project name is `blog-bkandcc-com`, so the fallback hostname is `blog-bkandcc-com.pages.dev`:

1. Create the GitHub repo and push: `gh repo create briankung/blog.bkandcc.com --public --source . --push`.
2. Cloudflare dashboard → Workers & Pages → **Create application → Pages → Connect to Git**, pick `blog.bkandcc.com`.
3. Build settings:
   - Production branch: `main`
   - Build command: `zola build`
   - Build output directory: `public`
   - Root directory: *(leave blank)*
4. Environment variables: `ZOLA_VERSION=0.22.1` (match local `zola --version`; bump in lockstep when upgrading).
5. Custom domain: project → **Custom domains → Set up a domain** → `blog.bkandcc.com`. Do this **before** touching DNS; Cloudflare must know about the hostname or the CNAME below answers 522.
6. DNS: `bkandcc.com` is on **Namecheap's nameservers**, not Cloudflare's, and it must stay there because the domain's email forwarding (`eforward*.registrar-servers.com` MX) only works on Namecheap DNS. So in Namecheap → Domain List → Manage → Advanced DNS, add:

   | Type  | Host   | Value                        | TTL       |
   |-------|--------|------------------------------|-----------|
   | CNAME | `blog` | `blog-bkandcc-com.pages.dev` | Automatic |

   Then back in the Pages custom-domain screen, click through the verification; it flips to Active once the CNAME propagates (the `.pages.dev` target serves the TLS certificate).

`static/CNAME` is kept for portability but Cloudflare Pages ignores it.

**Every push:**

- Push to `main` → Cloudflare builds and deploys automatically.
- To preview a branch, push it; Cloudflare creates a preview URL.

```bash
just deploy      # safety-check that you're on main, then git push origin main
just open-site   # open https://blog.bkandcc.com
just open-dash   # open the Cloudflare Pages dashboard
```
