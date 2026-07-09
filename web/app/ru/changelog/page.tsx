import ChangelogView from "@/components/pages/ChangelogView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("changelog", "ru", ChangelogView);

export const metadata = page.metadata;
export default page.Page;
