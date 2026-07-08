import type { Metadata } from "next";
import TermsView from "@/components/pages/TermsView";

export const metadata: Metadata = {
  title: "Terms of Use",
  description: "The terms that apply when you use the WeekFit app.",
};

export default function Page() {
  return <TermsView />;
}
