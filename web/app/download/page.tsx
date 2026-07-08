import DownloadView from "@/components/pages/DownloadView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "Install WeekFit on iPhone via TestFlight. An AI fitness coach that reads Apple Health data for recovery, activity and nutrition.";

export const metadata = pageMetadata({
  path: "/download",
  title: "Download",
  description,
  socialTitle: "Download WeekFit for iPhone",
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
