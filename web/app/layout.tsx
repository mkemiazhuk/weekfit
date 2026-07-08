import type { Metadata } from "next";
import "./globals.css";
import { I18nProvider } from "@/lib/i18n";
import SmoothScroll from "@/components/SmoothScroll";
import AtmosphereBackground from "@/components/AtmosphereBackground";
import Nav from "@/components/Nav";
import Footer from "@/components/Footer";

const siteUrl = "https://weekfit.app";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "WeekFit — A calm AI coach that understands your day",
    template: "%s — WeekFit",
  },
  description:
    "WeekFit reads your sleep, activity, nutrition and recovery from Apple Health, then tells you the one thing that matters today. Private by design.",
  applicationName: "WeekFit",
  keywords: [
    "WeekFit",
    "AI fitness coach",
    "Apple Health",
    "recovery",
    "nutrition",
    "activity",
    "wellness",
  ],
  openGraph: {
    type: "website",
    url: siteUrl,
    title: "WeekFit — A calm AI coach that understands your day",
    description:
      "It doesn't just collect health data. It understands your day. Built around Apple Health, private by design.",
    siteName: "WeekFit",
    images: [{ url: "/img/today.jpg", width: 900, height: 1950 }],
  },
  twitter: {
    card: "summary_large_image",
    title: "WeekFit — A calm AI coach that understands your day",
    description:
      "It doesn't just collect health data. It understands your day.",
    images: ["/img/today.jpg"],
  },
  icons: {
    icon: "/brand/icon-192.png",
    apple: "/brand/icon-180.png",
  },
  manifest: "/manifest.webmanifest",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full">
        <I18nProvider>
          <SmoothScroll />
          <AtmosphereBackground />
          <Nav />
          <main>{children}</main>
          <Footer />
        </I18nProvider>
      </body>
    </html>
  );
}
