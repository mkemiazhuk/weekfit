import TermsView from "@/components/pages/TermsView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "The terms that apply when you use the WeekFit app, including the health and wellness disclaimer.";

export const metadata = pageMetadata({
  path: "/terms",
  title: "Terms of Use",
  description,
  keywords: ["WeekFit terms", "terms of use", "fitness app terms"],
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          webPageSchema({
            path: "/terms",
            name: "Terms of Use",
            description,
            dateModified: "2026-07-08",
          }),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Terms of Use", path: "/terms" },
          ]),
        ]}
      />
      <TermsView />
    </>
  );
}
