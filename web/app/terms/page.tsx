import TermsView from "@/components/pages/TermsView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, termsOfServiceSchema } from "@/lib/schema";

const description =
  "Terms of use for the WeekFit iPhone app, including the health and wellness disclaimer.";

export const metadata = pageMetadata({
  path: "/terms",
  title: "Terms of Use",
  description,
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          termsOfServiceSchema({ description, dateModified: "2026-07-08" }),
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
