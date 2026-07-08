import DownloadView from "@/components/pages/DownloadView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "Join the WeekFit public beta on TestFlight for iPhone. A calm AI fitness coach built around Apple Health — private by design, free, no account required.";

export const metadata = pageMetadata({
  path: "/download",
  title: "Download",
  description,
  socialTitle: "Download WeekFit — Join the iPhone Beta",
  keywords: [
    "download WeekFit",
    "WeekFit TestFlight",
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
          webPageSchema({
            path: "/download",
            name: "Download WeekFit",
            description,
          }),
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
