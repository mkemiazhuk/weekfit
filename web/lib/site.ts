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
  title: "WeekFit — A calm AI coach that understands your day",
  description:
    "WeekFit is a calm AI fitness coach for iPhone. It reads your sleep, recovery, activity and nutrition from Apple Health, then tells you the one thing that matters today. Private by design, no account required.",
  // Primary + alternate locales (BCP-47 short codes for hreflang / inLanguage).
  defaultLocale: "en",
  locales: ["en", "ru"] as const,
  // Planned localizations (architecture is ready; content pending).
  plannedLocales: ["pl"] as const,
  // og:locale style tags.
  ogLocale: "en_US",
  ogAltLocales: ["ru_RU"],

  email: "support@weekfit.app",
  twitter: "@weekfit", // handle used for twitter:site / :creator (update if it changes)

  // Fill in when the app ships to enable the Safari Smart App Banner.
  // Example: "1234567890"
  appleAppId: process.env.NEXT_PUBLIC_APPLE_APP_ID || "",

  // Search Console / Webmaster verification tokens (rendered only when set).
  verification: {
    google: process.env.NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION || "",
    bing: process.env.NEXT_PUBLIC_BING_SITE_VERIFICATION || "",
    yandex: process.env.NEXT_PUBLIC_YANDEX_VERIFICATION || "",
  },

  // Privacy-friendly analytics (rendered only when configured). Plausible preferred.
  analytics: {
    plausibleDomain: process.env.NEXT_PUBLIC_PLAUSIBLE_DOMAIN || "",
    plausibleSrc:
      process.env.NEXT_PUBLIC_PLAUSIBLE_SRC ||
      "https://plausible.io/js/script.js",
    gaId: process.env.NEXT_PUBLIC_GA_ID || "",
  },

  // Natural keyword set (used as sensible page defaults — never stuffed).
  keywords: [
    "WeekFit",
    "AI fitness coach",
    "Apple Health app",
    "recovery tracking",
    "recovery score",
    "sleep analysis",
    "nutrition tracking",
    "workout planner",
    "activity tracking",
    "daily fitness coach",
    "health dashboard",
    "workout recovery",
    "health coaching",
  ],

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
