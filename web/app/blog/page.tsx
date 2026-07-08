import BlogView from "@/components/pages/BlogView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "Guides on recovery, sleep, nutrition and training — and how an AI fitness coach turns Apple Health data into daily guidance.";

export const metadata = pageMetadata({
  path: "/blog",
  title: "Blog",
  description,
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          webPageSchema({
            path: "/blog",
            name: "WeekFit Blog",
            description,
            type: "CollectionPage",
          }),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Blog", path: "/blog" },
          ]),
        ]}
      />
      <BlogView />
    </>
  );
}
