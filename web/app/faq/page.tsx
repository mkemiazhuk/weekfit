import type { Metadata } from "next";
import FaqView from "@/components/pages/FaqView";

export const metadata: Metadata = {
  title: "FAQ",
  description: "Answers to common questions about WeekFit, organized by topic.",
};

export default function Page() {
  return <FaqView />;
}
