// ============================================================
// Central site + SEO configuration.
// Single source of truth for URLs, identity, verification and
// analytics. Everything else (metadata, schema, sitemap, OG
// images) derives from here.
// ============================================================

export const SITE = {
  url: "https://weekfit.app",
  name: "WeekFit",
  shortName: "WeekFit",
  title: "WeekFit — AI Fitness Coach for iPhone",
  description:
    "WeekFit is an AI fitness coach for iPhone. It reads sleep, recovery, activity and nutrition from Apple Health and tells you what matters today. Private by design, no account required.",
  slogan: "Your day, understood.",
  defaultLocale: "en",
  locales: ["en", "ru"] as const,
  plannedLocales: ["pl"] as const,
  ogLocale: "en_US",

  email: "support@weekfit.app",
  twitter: "@weekfit", // twitter:site / :creator — update if the handle changes

  /**
   * Single install destination for CTAs and SoftwareApplication.downloadUrl.
   * At App Store launch, replace with the public App Store URL only here.
   */
  appInstallUrl: "https://testflight.apple.com/join/t5TKwEff",

  /**
   * Official social / entity profiles (Organization.sameAs).
   * Add URLs when accounts exist — do not use install links or placeholders.
   */
  sameAs: [] as string[],

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

  featureList: [
    "AI coach that reads recovery, activity, nutrition and sleep",
    "Daily readiness and recovery score",
    "Apple Health integration",
    "Nutrition and hydration tracking",
    "Weekly workout planning",
    "On-device, private by design",
  ],
} as const;

/** Absolute, trailing-slash URL for a path. `/` stays `/`. */
export function abs(path: string): string {
  if (!path || path === "/") return `${SITE.url}/`;
  const clean = path.replace(/^\/+|\/+$/g, "");
  return `${SITE.url}/${clean}/`;
}
