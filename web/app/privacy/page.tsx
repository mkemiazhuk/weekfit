import PrivacyView from "@/components/pages/PrivacyView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, privacyPolicySchema } from "@/lib/schema";

const description =
  "How WeekFit handles your data: local-first storage, Apple Health integration, no server upload, no advertising, no data sales.";

export const metadata = pageMetadata({
  path: "/privacy",
  title: "Privacy Policy",
  description,
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          privacyPolicySchema({ description, dateModified: "2026-07-08" }),
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
