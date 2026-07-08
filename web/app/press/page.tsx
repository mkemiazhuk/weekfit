import PressView from "@/components/pages/PressView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "WeekFit press kit — brand assets, product screenshots, boilerplate and media contact.";

export const metadata = pageMetadata({
  path: "/press",
  title: "Press Kit",
  description,
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          webPageSchema({ path: "/press", name: "Press Kit", description }),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Press Kit", path: "/press" },
          ]),
        ]}
      />
      <PressView />
    </>
  );
}
