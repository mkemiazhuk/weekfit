import ChangelogView from "@/components/pages/ChangelogView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";

const description =
  "WeekFit release history and what's coming next — new features, improvements and fixes, one release at a time.";

export const metadata = pageMetadata({
  path: "/changelog",
  title: "Changelog",
  description,
  socialTitle: "WeekFit Changelog — Release Notes",
  keywords: ["WeekFit changelog", "WeekFit updates", "WeekFit release notes"],
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
