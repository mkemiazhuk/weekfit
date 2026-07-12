# Social profiles & TestFlight — link weekfit.app

Backlinks from official profiles help Google associate the brand with the domain. Update each platform manually (no API in this repo).

## Instagram — @weekfit.app

**Profile:** https://www.instagram.com/weekfit.app/

1. Instagram app → Profile → **Edit profile**
2. **Website:** `https://weekfit.app`
3. **Bio** (copy-paste):

```
AI coach for recovery, sleep & training — powered by Apple Health
Private on your iPhone.
weekfit.app
```

4. Save

On-site short link for QR / link-in-bio tools: `https://weekfit.app/instagram/`

---

## X (Twitter) — @weekfit

**Status:** `https://x.com/weekfit` returns 404 — create the account first, then add the link.

1. Register **@weekfit** at https://x.com/i/flow/signup
2. Display name: `WeekFit`
3. Bio:

```
One clear call for today. AI fitness coach powered by Apple Health — private on your iPhone.
https://weekfit.app
```

4. **Website:** `https://weekfit.app`

After the profile is live, schema `sameAs` in `web/lib/site.ts` will resolve correctly.

---

## TestFlight public beta

**Link:** https://testflight.apple.com/join/t5TKwEff

1. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → WeekFit → **TestFlight**
2. Open the **Public Link** (or External Testing group with public link enabled)
3. Edit **Beta App Description** — append:

```
Learn more: https://weekfit.app
Download & support: https://weekfit.app/download/
```

4. Save

Current public page shows app description but no website URL — adding it gives Google another crawl path to the domain.

---

## Google Search Console (after deploy)

1. https://search.google.com/search-console → add property `weekfit.app`
2. Verify via **HTML file** (`googlebe868e9843b46f53.html` is already on the site) **or** **HTML tag** (meta is baked into builds; token `be868e9843b46f53`)
3. Submit sitemap: `https://weekfit.app/sitemap.xml`
4. **URL Inspection** → `https://weekfit.app/` → **Request indexing**

### GitHub Actions secret (optional)

`GOOGLE_SITE_VERIFICATION` in repo secrets can override the baked-in token. If unset, deploy still emits the meta tag. To set explicitly:

```bash
gh secret set GOOGLE_SITE_VERIFICATION --body "be868e9843b46f53"
```

Value must match the token from Search Console (HTML tag method) or the filename suffix of the verification HTML file.
