import BlogView from "@/components/pages/BlogView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "Guides and insights on recovery, sleep, nutrition and training — and how a daily AI fitness coach helps you act on them.";

export const metadata = pageMetadata({
  path: "/blog",
  title: "Blog",
  description,
  keywords: [
    "fitness blog",
    "recovery insights",
    "sleep analysis",
    "nutrition tracking",
    "training guides",
    "Apple Health tips",
  ],
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          webPageSchema({
            path: "/blog",
            name: "Blog",
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
