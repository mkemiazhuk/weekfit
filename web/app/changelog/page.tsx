import type { Metadata } from "next";
import ChangelogView from "@/components/pages/ChangelogView";

export const metadata: Metadata = {
  title: "Changelog",
  description: "WeekFit release history and what's coming next.",
};

export default function Page() {
  return <ChangelogView />;
}
