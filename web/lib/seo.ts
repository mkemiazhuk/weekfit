import type { Metadata } from "next";
import { SITE, abs } from "./site";

export interface PageSeo {
  path: string;
  title: string;
  description: string;
  /** Full OG/Twitter title override (defaults to "<title> — WeekFit"). */
  socialTitle?: string;
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

function ogImageUrl(path: string): string {
  const base = path === "/" ? SITE.url : abs(path).replace(/\/$/, "");
  return `${base}/opengraph-image.png`;
}

export function pageMetadata(seo: PageSeo): Metadata {
  const url = abs(seo.path);
  const index = seo.index ?? true;
  const social =
    seo.socialTitle ?? (seo.path === "/" ? SITE.title : `${seo.title} — ${SITE.name}`);
  const ogImage = ogImageUrl(seo.path);

  return {
    title: seo.path === "/" ? undefined : seo.title,
    description: seo.description,
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
