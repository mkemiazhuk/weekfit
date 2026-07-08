import PrivacyView from "@/components/pages/PrivacyView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "How WeekFit handles your data: local-first, powered by Apple Health, never uploaded to a server, never sold, and never used for advertising.";

export const metadata = pageMetadata({
  path: "/privacy",
  title: "Privacy Policy",
  description,
  keywords: [
    "WeekFit privacy",
    "Apple Health privacy",
    "health data privacy",
    "local-first fitness app",
    "HealthKit privacy",
  ],
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          webPageSchema({
            path: "/privacy",
            name: "Privacy Policy",
            description,
            dateModified: "2026-07-08",
          }),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Privacy Policy", path: "/privacy" },
          ]),
        ]}
      />
      <PrivacyView />
    </>
  );
}
