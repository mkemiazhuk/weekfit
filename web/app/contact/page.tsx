import ContactView from "@/components/pages/ContactView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";
import { SITE } from "@/lib/site";

const description =
  "Get in touch with the WeekFit team. Questions, feedback or an issue — we read every email at support@weekfit.app.";

export const metadata = pageMetadata({
  path: "/contact",
  title: "Contact",
  description,
  socialTitle: "Contact WeekFit — support@weekfit.app",
  keywords: ["WeekFit contact", "WeekFit support email", "contact WeekFit"],
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
          {
            "@context": "https://schema.org",
            "@type": "ContactPoint",
            email: SITE.email,
            contactType: "customer support",
            url: "https://weekfit.app/contact/",
            availableLanguage: ["English", "Russian"],
          },
        ]}
      />
      <ContactView />
    </>
  );
}
