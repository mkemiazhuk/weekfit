import { SITE, abs } from "./site";
import { support } from "./content";

const ORG_ID = `${SITE.url}/#organization`;
const SITE_ID = `${SITE.url}/#website`;
const APP_ID = `${SITE.url}/#app`;

type Json = Record<string, unknown>;

export function organizationSchema(): Json {
  const schema: Json = {
    "@context": "https://schema.org",
    "@type": "Organization",
    "@id": ORG_ID,
    name: SITE.name,
    url: SITE.url,
    logo: `${SITE.url}/brand/icon-512.png`,
    description: SITE.description,
    contactPoint: {
      "@type": "ContactPoint",
      email: SITE.email,
      contactType: "customer support",
      availableLanguage: ["English", "Russian"],
      url: abs("contact"),
    },
  };
  if (SITE.sameAs.length > 0) {
    schema.sameAs = [...SITE.sameAs];
  }
  return schema;
}

export function websiteSchema(): Json {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "@id": SITE_ID,
    url: SITE.url,
    name: SITE.name,
    description: SITE.description,
    inLanguage: SITE.defaultLocale,
    publisher: { "@id": ORG_ID },
  };
}

/**
 * SoftwareApplication — properties aligned with Google's documented fields:
 * https://developers.google.com/search/docs/appearance/structured-data/software-app
 */
export function softwareApplicationSchema(): Json {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "@id": APP_ID,
    name: SITE.name,
    applicationCategory: "HealthApplication",
    operatingSystem: "iOS",
    description: SITE.description,
    url: SITE.url,
    downloadUrl: SITE.appInstallUrl,
    image: `${SITE.url}/brand/icon-512.png`,
    screenshot: [
      `${SITE.url}/img/today.jpg`,
      `${SITE.url}/img/coach.jpg`,
      `${SITE.url}/img/activity.jpg`,
      `${SITE.url}/img/nutrition.jpg`,
    ],
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
    },
    publisher: { "@id": ORG_ID },
  };
}

export function webPageSchema(opts: {
  path: string;
  name: string;
  description: string;
  type?: string;
  dateModified?: string;
  datePublished?: string;
}): Json {
  return {
    "@context": "https://schema.org",
    "@type": opts.type ?? "WebPage",
    "@id": `${abs(opts.path)}#webpage`,
    url: abs(opts.path),
    name: opts.name,
    description: opts.description,
    isPartOf: { "@id": SITE_ID },
    inLanguage: SITE.defaultLocale,
    ...(opts.datePublished ? { datePublished: opts.datePublished } : {}),
    ...(opts.dateModified ? { dateModified: opts.dateModified } : {}),
  };
}

export function privacyPolicySchema(opts: {
  description: string;
  dateModified: string;
}): Json {
  return {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "@id": `${abs("privacy")}#webpage`,
    url: abs("privacy"),
    name: "WeekFit Privacy Policy",
    description: opts.description,
    dateModified: opts.dateModified,
    isPartOf: { "@id": SITE_ID },
    inLanguage: SITE.defaultLocale,
    publisher: { "@id": ORG_ID },
  };
}

export function termsOfServiceSchema(opts: {
  description: string;
  dateModified: string;
}): Json {
  return {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "@id": `${abs("terms")}#webpage`,
    url: abs("terms"),
    name: "WeekFit Terms of Use",
    description: opts.description,
    dateModified: opts.dateModified,
    isPartOf: { "@id": SITE_ID },
    inLanguage: SITE.defaultLocale,
    publisher: { "@id": ORG_ID },
  };
}

export function faqSchema(qas: { q: string; a: string }[]): Json {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: qas.map(({ q, a }) => ({
      "@type": "Question",
      name: q,
      acceptedAnswer: { "@type": "Answer", text: a },
    })),
  };
}

export function breadcrumbSchema(items: { name: string; path: string }[]): Json {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((it, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: it.name,
      item: abs(it.path),
    })),
  };
}

/** English FAQ content — used for FAQPage schema on /faq only. */
export function allFaqs(): { q: string; a: string }[] {
  return support.en.categories.flatMap((c) => c.faqs);
}
