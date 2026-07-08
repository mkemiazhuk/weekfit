import ContactView from "@/components/pages/ContactView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "Get in touch with the WeekFit team. Questions, feedback or an issue — we read every email.";

export const metadata = pageMetadata({
  path: "/contact",
  title: "Contact",
  description,
  keywords: ["WeekFit contact", "WeekFit support email", "contact WeekFit"],
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          webPageSchema({
            path: "/contact",
            name: "Contact",
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
