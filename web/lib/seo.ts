import type { Metadata } from "next";
import { SITE, abs } from "./site";

export interface PageSeo {
  /** Route path, e.g. "/privacy". Use "/" for home. */
  path: string;
  /** Short page title (brand suffix is applied by the layout template). */
  title: string;
  description: string;
  keywords?: string[];
  /** Full OG/Twitter title override (defaults to "<title> — WeekFit"). */
  socialTitle?: string;
  /** Set false for pages that should not be indexed. */
  index?: boolean;
}

const robots = (index: boolean): Metadata["robots"] => ({
  index,
  follow: true,
  googleBot: {
    index,
    follow: true,
    "max-image-preview": "large",
    "max-snippet": -1,
    "max-video-preview": -1,
  },
});

/**
 * Build a complete, per-page Metadata object: unique title + description,
 * canonical URL, hreflang alternates, Open Graph + Twitter cards and robots
 * directives. Open Graph / Twitter images are supplied automatically by the
 * `opengraph-image` file convention, so they are intentionally not set here.
 */
export function pageMetadata(seo: PageSeo): Metadata {
  const url = abs(seo.path);
  const index = seo.index ?? true;
  const social =
    seo.socialTitle ?? (seo.path === "/" ? SITE.title : `${seo.title} — ${SITE.name}`);

  return {
    title: seo.path === "/" ? undefined : seo.title,
    description: seo.description,
    keywords: seo.keywords ?? [...SITE.keywords],
    alternates: {
      canonical: url,
      languages: {
        "x-default": url,
        en: url,
      },
    },
    openGraph: {
      type: "website",
      url,
      siteName: SITE.name,
      title: social,
      description: seo.description,
      locale: SITE.ogLocale,
      alternateLocale: [...SITE.ogAltLocales],
    },
    twitter: {
      card: "summary_large_image",
      site: SITE.twitter,
      creator: SITE.twitter,
      title: social,
      description: seo.description,
    },
    robots: robots(index),
  };
}
