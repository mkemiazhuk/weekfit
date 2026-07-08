import FaqView from "@/components/pages/FaqView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { allFaqs, breadcrumbSchema, faqSchema } from "@/lib/schema";

const description =
  "Frequently asked questions about WeekFit — the AI fitness coach, recovery score, Apple Health, nutrition tracking and privacy.";

export const metadata = pageMetadata({
  path: "/faq",
  title: "FAQ",
  description,
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          faqSchema(allFaqs()),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "FAQ", path: "/faq" },
          ]),
        ]}
      />
      <FaqView />
    </>
  );
}
