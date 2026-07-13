import { ENTITY, SITE, abs } from "./site";
import { absLocalized, type Locale } from "./locale";
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
    alternateName: [...ENTITY.alternateNames],
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
  node.sameAs = [...SITE.sameAs];
  return node;
}

function websiteNode(): Json {
  return {
    "@type": "WebSite",
    "@id": SITE_ID,
    url: SITE.url,
    name: ENTITY.name,
    alternateName: [...ENTITY.alternateNames],
    description: ENTITY.description,
    inLanguage: ["en", "ru"],
    publisher: { "@id": ORG_ID },
    about: { "@id": APP_ID },
  };
}

function softwareApplicationNode(): Json {
  return {
    "@type": "SoftwareApplication",
    "@id": APP_ID,
    name: ENTITY.name,
    alternateName: [...ENTITY.alternateNames],
    applicationCategory: "HealthApplication",
    operatingSystem: ENTITY.operatingSystem,
    description: ENTITY.description,
    url: SITE.url,
    downloadUrl: SITE.appInstallUrl,
    image: `${SITE.url}/brand/icon-512.png`,
    screenshot: [
      `${SITE.url}/img/today-760.webp`,
      `${SITE.url}/img/coach-760.webp`,
      `${SITE.url}/img/activity-760.webp`,
      `${SITE.url}/img/nutrition-760.webp`,
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
  locale?: Locale;
}): Json {
  const locale = opts.locale ?? "en";
  return {
    "@context": "https://schema.org",
    "@type": opts.type ?? "WebPage",
    "@id": `${absLocalized(opts.path, locale)}#webpage`,
    url: absLocalized(opts.path, locale),
    name: opts.name,
    description: opts.description,
    isPartOf: { "@id": SITE_ID },
    about: { "@id": APP_ID },
    inLanguage: locale,
    ...(opts.datePublished ? { datePublished: opts.datePublished } : {}),
    ...(opts.dateModified ? { dateModified: opts.dateModified } : {}),
  };
}

export function privacyPolicySchema(opts: {
  description: string;
  dateModified: string;
  locale?: Locale;
}): Json {
  const locale = opts.locale ?? "en";
  const url = absLocalized("privacy", locale);
  return {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "@id": `${url}#webpage`,
    url,
    name: locale === "ru" ? "Политика конфиденциальности WeekFit" : "WeekFit Privacy Policy",
    description: opts.description,
    dateModified: opts.dateModified,
    isPartOf: { "@id": SITE_ID },
    about: { "@id": APP_ID },
    inLanguage: locale,
    publisher: { "@id": ORG_ID },
  };
}

export function termsOfServiceSchema(opts: {
  description: string;
  dateModified: string;
  locale?: Locale;
}): Json {
  const locale = opts.locale ?? "en";
  const url = absLocalized("terms", locale);
  return {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "@id": `${url}#webpage`,
    url,
    name: locale === "ru" ? "Условия использования WeekFit" : "WeekFit Terms of Use",
    description: opts.description,
    dateModified: opts.dateModified,
    isPartOf: { "@id": SITE_ID },
    about: { "@id": APP_ID },
    inLanguage: locale,
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

export function breadcrumbSchema(
  items: { name: string; path: string }[],
  locale: Locale = "en"
): Json {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((it, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: it.name,
      item: absLocalized(it.path, locale),
    })),
  };
}

export function blogPostingSchema(opts: {
  path: string;
  headline: string;
  description: string;
  datePublished: string;
  dateModified?: string;
  locale: Locale;
  image?: string;
}): Json {
  const image = opts.image?.startsWith("http")
    ? opts.image
    : `${SITE.url}${opts.image ?? "/img/today-760.webp"}`;
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "@id": `${absLocalized(opts.path, opts.locale)}#article`,
    url: absLocalized(opts.path, opts.locale),
    headline: opts.headline,
    description: opts.description,
    datePublished: opts.datePublished,
    dateModified: opts.dateModified ?? opts.datePublished,
    inLanguage: opts.locale,
    author: { "@id": ORG_ID },
    publisher: { "@id": ORG_ID },
    isPartOf: { "@id": SITE_ID },
    about: { "@id": APP_ID },
    image,
  };
}

/** FAQ content for FAQPage schema. */
export function allFaqs(locale: Locale = "en"): { q: string; a: string }[] {
  return support[locale].categories.flatMap((c) => c.faqs);
}
