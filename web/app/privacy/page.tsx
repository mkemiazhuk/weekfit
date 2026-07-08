import type { Metadata } from "next";
import PrivacyView from "@/components/pages/PrivacyView";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "How WeekFit handles your data: local-first, powered by Apple Health, never sold, never used for advertising.",
};

export default function Page() {
  return <PrivacyView />;
}
