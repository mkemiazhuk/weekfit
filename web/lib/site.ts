// ============================================================
// Central site + entity configuration.
// Single source of truth for URLs, identity, verification and
// analytics. All schema, manifest, and llms.txt derive from here.
// ============================================================

/** Canonical machine-readable product identity. */
export const ENTITY = {
  name: "WeekFit",
  /** Spaced variant people often type in search. */
  alternateNames: ["Week Fit"] as const,
  developer: "WeekFit",
  description:
    "WeekFit reads Apple Health and gives you one clear decision every morning — push, hold, or recover — with visible reasoning. Private on your iPhone.",
  platform: "iPhone",
  operatingSystem: "iOS",
  category: "AI fitness coach",
  dataSource: "Apple Health",
} as const;

export const SITE = {
  url: "https://weekfit.app",
  name: ENTITY.name,
  shortName: ENTITY.name,
  title: `${ENTITY.name} — AI Fitness Coach for iPhone`,
  description: ENTITY.description,
  defaultLocale: "en",
  locales: ["en", "ru"] as const,
  plannedLocales: ["pl"] as const,
  ogLocale: "en_US",

  email: "support@weekfit.app",
  twitter: "@weekfit",

  social: {
    x: "https://x.com/weekfit",
    instagram: "https://instagram.com/weekfit",
  },

  /** Single install URL for CTAs and SoftwareApplication.downloadUrl. Swap at App Store launch. */
  appInstallUrl: "https://testflight.apple.com/join/t5TKwEff",

  /** Google Search “preferred source” deeplink (domain-level sites only). */
  googlePreferredSourceUrl: "https://google.com/preferences/source?q=weekfit.app",

  /** Official entity profiles (Organization.sameAs). */
  sameAs: [
    "https://x.com/weekfit",
    "https://instagram.com/weekfit",
  ] as const,

  appleAppId: process.env.NEXT_PUBLIC_APPLE_APP_ID || "",

  verification: {
    google: process.env.NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION || "",
    bing: process.env.NEXT_PUBLIC_BING_SITE_VERIFICATION || "",
    yandex: process.env.NEXT_PUBLIC_YANDEX_VERIFICATION || "",
  },

  analytics: {
    plausibleDomain: process.env.NEXT_PUBLIC_PLAUSIBLE_DOMAIN || "",
    plausibleSrc:
      process.env.NEXT_PUBLIC_PLAUSIBLE_SRC ||
      "https://plausible.io/js/script.js",
    gaId: process.env.NEXT_PUBLIC_GA_ID || "",
  },
} as const;

/** Absolute, trailing-slash URL for a path. `/` stays `/`. */
export function abs(path: string): string {
  if (!path || path === "/") return `${SITE.url}/`;
  const clean = path.replace(/^\/+|\/+$/g, "");
  return `${SITE.url}/${clean}/`;
}
