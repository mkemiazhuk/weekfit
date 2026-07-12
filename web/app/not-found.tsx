import type { Metadata } from "next";
import NotFoundView from "@/components/pages/NotFoundView";

export const metadata: Metadata = {
  title: "Page Not Found",
  description: "This page is not available on WeekFit.",
  robots: { index: false, follow: false },
  openGraph: {
    title: "Page Not Found — WeekFit",
    description: "This page is not available on WeekFit.",
  },
  twitter: {
    card: "summary",
    title: "Page Not Found — WeekFit",
    description: "This page is not available on WeekFit.",
  },
};

export default function NotFound() {
  return <NotFoundView />;
}
