import type { Metadata } from "next";
import DownloadView from "@/components/pages/DownloadView";

export const metadata: Metadata = {
  title: "Download",
  description:
    "Download WeekFit for iPhone. Built around Apple Health, private by design.",
};

export default function Page() {
  return <DownloadView />;
}
