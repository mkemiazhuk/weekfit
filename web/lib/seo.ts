import type { Metadata } from "next";
import { SITE } from "./site";
import { absLocalized, hreflangAlternates, type Locale } from "./locale";
import { ogImageUrl } from "./og-url";

export interface PageSeo {
  path: string;
  title: string;
  description: string;
  keywords?: string[];
  /** Full OG/Twitter title override (defaults to "<title> — WeekFit"). */
  socialTitle?: string;
  index?: boolean;
  locale?: Locale;
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

export function pageMetadata(seo: PageSeo): Metadata {
  const locale = seo.locale ?? "en";
  const url = absLocalized(seo.path, locale);
  const index = seo.index ?? true;
  const social =
    seo.socialTitle ?? (seo.path === "/" ? seo.title : `${seo.title} — ${SITE.name}`);
  const ogImage = ogImageUrl(seo.path);

  return {
    title: seo.path === "/" ? seo.title : seo.title,
    description: seo.description,
    ...(seo.keywords?.length ? { keywords: seo.keywords } : {}),
    alternates: {
      canonical: url,
      languages: hreflangAlternates(seo.path),
    },
    openGraph: {
      type: "website",
      url,
      siteName: SITE.name,
      title: social,
      description: seo.description,
      locale: locale === "ru" ? "ru_RU" : "en_US",
      alternateLocale: locale === "ru" ? ["en_US"] : ["ru_RU"],
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
