import type { Metadata } from "next";
import type { Locale } from "./locale";
import { pageMetadata } from "./seo";
import { HOME_SEO, PAGE_SEO, BREADCRUMB_HOME, type PageSeoCopy } from "./page-seo";

type PageKey = keyof typeof PAGE_SEO;

export function homeMetadata(locale: Locale): Metadata {
  const copy = HOME_SEO[locale];
  return pageMetadata({
    path: "/",
    locale,
    title: copy.title,
    description: copy.description,
    socialTitle: copy.socialTitle,
    keywords: copy.keywords,
  });
}

export function sitePageMetadata(key: PageKey, locale: Locale): Metadata {
  const copy: PageSeoCopy = PAGE_SEO[key][locale];
  return pageMetadata({
    path: `/${key}`,
    locale,
    title: copy.title,
    description: copy.description,
    socialTitle: copy.socialTitle,
  });
}

export function breadcrumbHome(locale: Locale): string {
  return BREADCRUMB_HOME[locale];
}
