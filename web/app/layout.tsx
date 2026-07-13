import type { Metadata, Viewport } from "next";
import { GeistSans } from "geist/font/sans";
import clsx from "clsx";
import "./globals.css";
import { I18nProvider } from "@/lib/i18n";
import ClientEnhancements from "@/components/ClientEnhancements";
import Nav from "@/components/Nav";
import Footer from "@/components/Footer";
import Analytics from "@/components/Analytics";
import JsonLd from "@/components/JsonLd";
import SkipLink from "@/components/SkipLink";
import { SITE } from "@/lib/site";
import { pageMetadata } from "@/lib/seo";
import { HOME_SEO } from "@/lib/page-seo";
import { entityGraphSchema } from "@/lib/schema";

const home = pageMetadata({
  path: "/",
  locale: "en",
  title: HOME_SEO.en.title,
  description: HOME_SEO.en.description,
});

const other: Record<string, string> = {};
if (SITE.verification.bing) other["msvalidate.01"] = SITE.verification.bing;
if (SITE.appleAppId) other["apple-itunes-app"] = `app-id=${SITE.appleAppId}`;

export const metadata: Metadata = {
  metadataBase: new URL(SITE.url),
  ...home,
  title: {
    default: SITE.title,
    template: `%s — ${SITE.name}`,
  },
  applicationName: SITE.name,
  authors: [{ name: "WeekFit", url: SITE.url }],
  creator: "WeekFit",
  publisher: "WeekFit",
  category: "health",
  formatDetection: { telephone: false, address: false, email: false },
  appleWebApp: {
    capable: true,
    title: "WeekFit",
    statusBarStyle: "black-translucent",
  },
  icons: {
    icon: [
      { url: "/brand/favicon-tab.png", type: "image/png", sizes: "192x192" },
      { url: "/brand/favicon-32.png", type: "image/png", sizes: "32x32" },
      { url: "/favicon.ico", sizes: "any" },
    ],
    shortcut: "/brand/favicon-tab.png",
    apple: [{ url: "/brand/favicon-tab.png", sizes: "192x192" }],
  },
  manifest: "/manifest.webmanifest",
  verification: {
    google: SITE.verification.google || undefined,
    yandex: SITE.verification.yandex || undefined,
  },
  ...(Object.keys(other).length ? { other } : {}),
};

export const viewport: Viewport = {
  themeColor: "#06070a",
  colorScheme: "dark",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={clsx(GeistSans.variable, "antialiased")}>
      <head>
        <link
          rel="icon"
          href="/brand/favicon-tab.png?v=5"
          type="image/png"
          sizes="192x192"
        />
        <link
          rel="preload"
          href="/img/today-560.webp"
          as="image"
          type="image/webp"
          fetchPriority="high"
          media="(max-width: 767px)"
        />
        <link
          rel="preload"
          href="/img/today-760.webp"
          as="image"
          type="image/webp"
          fetchPriority="high"
          media="(min-width: 768px)"
        />
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){var p=location.pathname;var l=(p==='/ru'||p.indexOf('/ru/')===0)?'ru':'en';document.documentElement.lang=l})();`,
          }}
        />
      </head>
      <body className="min-h-full">
        <JsonLd data={entityGraphSchema()} />
        <I18nProvider>
          <SkipLink />
          <ClientEnhancements />
          <Nav />
          <main id="main-content" className="relative z-0">
            {children}
          </main>
          <Footer />
        </I18nProvider>
        <Analytics />
      </body>
    </html>
  );
}
