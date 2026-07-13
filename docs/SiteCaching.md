# Site caching (PageSpeed “efficient cache lifetimes”)

## Why Lighthouse shows 10 minutes

[weekfit.app](https://weekfit.app) is on **GitHub Pages**. Every file is served with:

```http
cache-control: max-age=600
```

GitHub does not allow custom cache headers. The `_headers` file in `web/out/` is generated at build time for hosts that support it, but **GitHub Pages ignores it**.

That is why PageSpeed lists ~762 KiB of static assets with a **10m** TTL even after image optimization.

## Fix options (pick one)

### Option A — Cloudflare Pages (recommended, repo-ready)

Cloudflare Pages reads `web/out/_headers` and serves long-lived cache for JS, fonts, images, and mockify frames.

1. Create a [Cloudflare Pages](https://pages.cloudflare.com/) project named `weekfit`.
2. Add GitHub secrets to the repo:
   - `CLOUDFLARE_API_TOKEN` — token with **Cloudflare Pages Edit** permission
   - `CLOUDFLARE_ACCOUNT_ID` — from Cloudflare dashboard → Workers & Pages → right sidebar
3. Run the **Deploy Website (Cloudflare Pages)** workflow (Actions → workflow_dispatch), or push to `main` once the workflow is enabled.
4. In Cloudflare Pages → **Custom domains**, attach `weekfit.app` and `www.weekfit.app`.
5. Update DNS at your registrar to Cloudflare nameservers (if not already on Cloudflare), or point the domain CNAME to the Pages URL as instructed.

After cutover, re-run PageSpeed — static assets should show **1 year** cache TTL.

To regenerate headers locally:

```bash
cd web && npm run build
# inspect web/out/_headers
```

### Option B — Keep GitHub Pages, add Cloudflare CDN in front

If you want to stay on GitHub Pages but fix browser cache headers:

1. Add `weekfit.app` to Cloudflare (DNS → nameservers at registrar).
2. Keep the GitHub Pages CNAME target (`<user>.github.io` or the Pages default).
3. Create **Cache Rules** (Caching → Cache Rules):

| Setting | Value |
|--------|--------|
| **When** | URI Path contains `/_next/static/` **OR** `/img/` **OR** `/mockify/` **OR** `/brand/` |
| **Cache eligibility** | Eligible for cache |
| **Edge TTL** | Ignore cache-control header → **1 year** |
| **Browser Cache TTL** | Override origin → **1 year** |

4. Purge cache once after saving rules.

Lighthouse reads the **response** `Cache-Control` header. Overriding browser TTL at Cloudflare fixes the audit without changing the deploy pipeline.

### Option C — Do nothing

First-visit performance is unchanged. Repeat visits within 10 minutes benefit from cache; after that, assets re-download. PageSpeed cache score stays low.

## What we ship in `_headers`

After `npm run build`, `web/out/_headers` contains:

- `/_next/static/*`, `/img/*`, `/mockify/*`, `/brand/*` → **1 year, immutable**
- HTML entry routes → **1 hour** with stale-while-revalidate

This matches Lighthouse’s “long cache lifetime” threshold (30+ days for static assets).
