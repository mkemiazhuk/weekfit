import ChangelogView from "@/components/pages/ChangelogView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "WeekFit release notes — new features, improvements and fixes.";

export const metadata = pageMetadata({
  path: "/changelog",
  title: "Changelog",
  description,
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          webPageSchema({
            path: "/changelog",
            name: "WeekFit Changelog",
            description,
          }),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "Changelog", path: "/changelog" },
          ]),
        ]}
      />
      <ChangelogView />
    </>
  );
}
