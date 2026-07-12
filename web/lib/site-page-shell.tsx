import type { ComponentType } from "react";
import JsonLd from "@/components/JsonLd";
import { sitePageMetadata, breadcrumbHome } from "./page-factory";
import { PAGE_SEO } from "./page-seo";
import type { Locale } from "./locale";
import {
  allFaqs,
  breadcrumbSchema,
  faqSchema,
  privacyPolicySchema,
  termsOfServiceSchema,
  webPageSchema,
} from "./schema";

type PageKey = keyof typeof PAGE_SEO;

export function buildSitePage(
  key: PageKey,
  locale: Locale,
  View: ComponentType
) {
  const copy = PAGE_SEO[key][locale];
  const path = `/${key}`;

  function Page() {
    const crumbs = breadcrumbSchema(
      [
        { name: breadcrumbHome(locale), path: "/" },
        { name: copy.title, path },
      ],
      locale
    );

    let primary: object;
    if (key === "faq") {
      primary = faqSchema(allFaqs(locale));
    } else if (key === "privacy") {
      primary = privacyPolicySchema({
        description: copy.description,
        dateModified: "2026-07-08",
        locale,
      });
    } else if (key === "terms") {
      primary = termsOfServiceSchema({
        description: copy.description,
        dateModified: "2026-07-08",
        locale,
      });
    } else {
      primary = webPageSchema({
        path,
        name: key === "blog" ? "WeekFit Blog" : `WeekFit ${copy.title}`,
        description: copy.description,
        type: key === "blog" ? "CollectionPage" : undefined,
        locale,
      });
    }

    return (
      <>
        <JsonLd data={[primary, crumbs]} />
        <View />
      </>
    );
  }

  return {
    metadata: sitePageMetadata(key, locale),
    Page,
  };
}
