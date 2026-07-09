import type { Metadata, Viewport } from "next";
import "./globals.css";
import { I18nProvider } from "@/lib/i18n";
import SmoothScroll from "@/components/SmoothScroll";
import AtmosphereBackground from "@/components/AtmosphereBackground";
import Nav from "@/components/Nav";
import Footer from "@/components/Footer";
import Analytics from "@/components/Analytics";
import JsonLd from "@/components/JsonLd";
import SkipLink from "@/components/SkipLink";
import ScrollProgress from "@/components/ScrollProgress";
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
      { url: "/favicon.ico", sizes: "any" },
      { url: "/brand/icon-192.png", type: "image/png", sizes: "192x192" },
      { url: "/brand/icon-512.png", type: "image/png", sizes: "512x512" },
    ],
    shortcut: "/brand/icon-192.png",
    apple: [{ url: "/brand/icon-180.png", sizes: "180x180" }],
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
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="h-full antialiased">
      <head>
        <link rel="preload" href="/img/today.jpg" as="image" type="image/jpeg" />
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
          <ScrollProgress />
          <SmoothScroll />
          <AtmosphereBackground />
          <Nav />
          <main id="main-content">{children}</main>
          <Footer />
        </I18nProvider>
        <Analytics />
      </body>
    </html>
  );
}
