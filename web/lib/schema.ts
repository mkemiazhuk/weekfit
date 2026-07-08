import { SITE, abs } from "./site";
import { support } from "./content";

const ORG_ID = `${SITE.url}/#organization`;
const SITE_ID = `${SITE.url}/#website`;
const APP_ID = `${SITE.url}/#app`;

type Json = Record<string, unknown>;

export function organizationSchema(): Json {
  return {
    "@context": "https://schema.org",
    "@type": "Organization",
    "@id": ORG_ID,
    name: SITE.name,
    url: SITE.url,
    logo: {
      "@type": "ImageObject",
      url: `${SITE.url}/brand/icon-512.png`,
      width: 512,
      height: 512,
    },
    email: SITE.email,
    description: SITE.description,
    slogan: SITE.slogan,
    knowsAbout: [
      "AI fitness coaching",
      "Apple Health",
      "Recovery tracking",
      "Sleep analysis",
      "Nutrition tracking",
      "Workout planning",
    ],
    contactPoint: [
      {
        "@type": "ContactPoint",
        email: SITE.email,
        contactType: "customer support",
        availableLanguage: ["English", "Russian"],
        url: abs("contact"),
      },
    ],
    sameAs: [...SITE.sameAs],
  };
}

export function websiteSchema(): Json {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "@id": SITE_ID,
    url: SITE.url,
    name: SITE.name,
    description: SITE.description,
    inLanguage: [...SITE.locales],
    publisher: { "@id": ORG_ID },
    // SearchAction: support page reads ?q= and filters FAQs client-side.
    potentialAction: {
      "@type": "SearchAction",
      target: {
        "@type": "EntryPoint",
        urlTemplate: `${abs("support")}?q={search_term_string}`,
      },
      "query-input": "required name=search_term_string",
    },
  };
}

/** Primary app entity — dual-typed for SoftwareApplication + MobileApplication rich results. */
export function softwareApplicationSchema(): Json {
  return {
    "@context": "https://schema.org",
    "@type": ["SoftwareApplication", "MobileApplication"],
    "@id": APP_ID,
    name: SITE.name,
    applicationCategory: "HealthApplication",
    applicationSubCategory: "Fitness",
    operatingSystem: "iOS 17.0 or later",
    description: SITE.description,
    url: SITE.url,
    downloadUrl: SITE.testflightUrl,
    installUrl: SITE.testflightUrl,
    image: `${SITE.url}/brand/icon-512.png`,
    screenshot: [
      `${SITE.url}/img/today.jpg`,
      `${SITE.url}/img/coach.jpg`,
      `${SITE.url}/img/activity.jpg`,
      `${SITE.url}/img/nutrition.jpg`,
    ],
    softwareVersion: "1.0",
    datePublished: "2026-07-08",
    inLanguage: [...SITE.locales],
    featureList: [...SITE.featureList],
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
    },
    author: { "@id": ORG_ID },
    publisher: { "@id": ORG_ID },
    isAccessibleForFree: true,
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
    "@type": "PrivacyPolicy",
    "@id": `${abs("privacy")}#privacy-policy`,
    url: abs("privacy"),
    name: "WeekFit Privacy Policy",
    description: opts.description,
    dateModified: opts.dateModified,
    datePublished: "2026-07-08",
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
    "@type": "TermsOfService",
    "@id": `${abs("terms")}#terms-of-service`,
    url: abs("terms"),
    name: "WeekFit Terms of Use",
    description: opts.description,
    dateModified: opts.dateModified,
    datePublished: "2026-07-08",
    isPartOf: { "@id": SITE_ID },
    inLanguage: SITE.defaultLocale,
    publisher: { "@id": ORG_ID },
  };
}

export function faqSchema(qas: { q: string; a: string }[]): Json {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "@id": `${abs("faq")}#faq`,
    url: abs("faq"),
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

/** Every support/FAQ Q&A, flattened — the indexable knowledge base (English). */
export function allFaqs(): { q: string; a: string }[] {
  return support.en.categories.flatMap((c) => c.faqs);
}
