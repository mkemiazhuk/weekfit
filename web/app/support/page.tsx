import SupportView from "@/components/pages/SupportView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "WeekFit Help Center — setup guides and answers for Apple Health, recovery tracking, nutrition, activities, the AI Coach, planning and troubleshooting.";

export const metadata = pageMetadata({
  path: "/support",
  title: "Support",
  description,
  socialTitle: "WeekFit Help Center — Setup & Troubleshooting",
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
          webPageSchema({
            path: "/support",
            name: "WeekFit Help Center",
            description,
          }),
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
