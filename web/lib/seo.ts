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

/** Absolute URL for the per-route OG image (post-build .png extension). */
function ogImageUrl(path: string): string {
  const base = path === "/" ? SITE.url : abs(path).replace(/\/$/, "");
  return `${base}/opengraph-image.png`;
}

/**
 * Build a complete, per-page Metadata object: unique title + description,
 * canonical URL, hreflang alternates, Open Graph + Twitter cards and robots
 * directives.
 */
export function pageMetadata(seo: PageSeo): Metadata {
  const url = abs(seo.path);
  const index = seo.index ?? true;
  const social =
    seo.socialTitle ?? (seo.path === "/" ? SITE.title : `${seo.title} — ${SITE.name}`);
  const ogImage = ogImageUrl(seo.path);

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
      images: [
        {
          url: ogImage,
          width: 1200,
          height: 630,
          alt: social,
          type: "image/png",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      site: SITE.twitter,
      creator: SITE.twitter,
      title: social,
      description: seo.description,
      images: [ogImage],
    },
    robots: robots(index),
  };
}
