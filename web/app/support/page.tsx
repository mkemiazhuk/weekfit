import SupportView from "@/components/pages/SupportView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { allFaqs, breadcrumbSchema, faqSchema } from "@/lib/schema";

const description =
  "WeekFit Help Center — setup guides and answers for Apple Health, recovery tracking, nutrition, activities, the AI Coach, planning and troubleshooting.";

export const metadata = pageMetadata({
  path: "/support",
  title: "Support",
  description,
  keywords: [
    "WeekFit support",
    "WeekFit help",
    "Apple Health setup",
    "recovery tracking help",
    "fitness app troubleshooting",
  ],
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          faqSchema(allFaqs()),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Support", path: "/support" },
          ]),
        ]}
      />
      <SupportView />
    </>
  );
}
