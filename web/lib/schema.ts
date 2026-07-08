import { ENTITY, SITE, abs } from "./site";
import { support } from "./content";

const ORG_ID = `${SITE.url}/#organization`;
const SITE_ID = `${SITE.url}/#website`;
const APP_ID = `${SITE.url}/#app`;

type Json = Record<string, unknown>;

function organizationNode(): Json {
  const node: Json = {
    "@type": "Organization",
    "@id": ORG_ID,
    name: ENTITY.developer,
    url: SITE.url,
    logo: `${SITE.url}/brand/icon-512.png`,
    description: ENTITY.description,
    contactPoint: {
      "@type": "ContactPoint",
      email: SITE.email,
      contactType: "customer support",
      availableLanguage: ["English", "Russian"],
      url: abs("contact"),
    },
  };
  if (SITE.sameAs.length > 0) {
    node.sameAs = [...SITE.sameAs];
  }
  return node;
}

function websiteNode(): Json {
  return {
    "@type": "WebSite",
    "@id": SITE_ID,
    url: SITE.url,
    name: ENTITY.name,
    description: ENTITY.description,
    inLanguage: SITE.defaultLocale,
    publisher: { "@id": ORG_ID },
    about: { "@id": APP_ID },
  };
}

function softwareApplicationNode(): Json {
  return {
    "@type": "SoftwareApplication",
    "@id": APP_ID,
    name: ENTITY.name,
    applicationCategory: "HealthApplication",
    operatingSystem: ENTITY.operatingSystem,
    description: ENTITY.description,
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
    author: { "@id": ORG_ID },
    publisher: { "@id": ORG_ID },
  };
}

/** Connected entity graph — Organization, WebSite, and SoftwareApplication as one product. */
export function entityGraphSchema(): Json {
  return {
    "@context": "https://schema.org",
    "@graph": [organizationNode(), websiteNode(), softwareApplicationNode()],
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
    about: { "@id": APP_ID },
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
    about: { "@id": APP_ID },
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
    about: { "@id": APP_ID },
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
    about: { "@id": APP_ID },
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

/** English FAQ content — FAQPage schema on /faq only. */
export function allFaqs(): { q: string; a: string }[] {
  return support.en.categories.flatMap((c) => c.faqs);
}
