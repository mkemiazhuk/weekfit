import ContactView from "@/components/pages/ContactView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "Contact the WeekFit team at support@weekfit.app for questions, feedback or issues.";

export const metadata = pageMetadata({
  path: "/contact",
  title: "Contact",
  description,
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          webPageSchema({
            path: "/contact",
            name: "Contact WeekFit",
            description,
            type: "ContactPage",
          }),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Contact", path: "/contact" },
          ]),
        ]}
      />
      <ContactView />
    </>
  );
}
