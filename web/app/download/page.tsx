import DownloadView from "@/components/pages/DownloadView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import {
  breadcrumbSchema,
  softwareApplicationSchema,
} from "@/lib/schema";

const description =
  "Download WeekFit for iPhone — a calm AI fitness coach built around Apple Health. Private by design, no account required. Free.";

export const metadata = pageMetadata({
  path: "/download",
  title: "Download",
  description,
  keywords: [
    "download WeekFit",
    "WeekFit iPhone app",
    "AI fitness coach app",
    "Apple Health fitness app",
  ],
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          softwareApplicationSchema(),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Download", path: "/download" },
          ]),
        ]}
      />
      <DownloadView />
    </>
  );
}
