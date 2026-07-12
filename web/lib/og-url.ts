import { SITE } from "./site";

/** App routes that ship a dedicated `app/{segment}/opengraph-image.tsx`. */
const CUSTOM_OG_SEGMENTS = new Set([
  "download",
  "support",
  "faq",
  "blog",
  "privacy",
  "terms",
  "press",
  "contact",
  "changelog",
  "experience",
]);

/**
 * OG images are generated once under English app routes and reused for all locales.
 * Social scrapers must never receive a locale-prefixed path that has no PNG on disk.
 */
export function ogImageUrl(path: string): string {
  const normalized = path.replace(/^\/+|\/+$/g, "");
  if (!normalized) {
    return `${SITE.url}/opengraph-image.png`;
  }
  const first = normalized.split("/")[0];
  if (first === "blog") {
    return `${SITE.url}/blog/opengraph-image.png`;
  }
  if (CUSTOM_OG_SEGMENTS.has(first)) {
    return `${SITE.url}/${first}/opengraph-image.png`;
  }
  return `${SITE.url}/opengraph-image.png`;
}
