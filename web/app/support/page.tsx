import SupportView from "@/components/pages/SupportView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "WeekFit Help Center — guides for Apple Health setup, recovery tracking, nutrition, the AI Coach and troubleshooting.";

export const metadata = pageMetadata({
  path: "/support",
  title: "Support",
  description,
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
