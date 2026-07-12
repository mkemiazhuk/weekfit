import ChangelogView from "@/components/pages/ChangelogView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("changelog", "en", ChangelogView);
export { metadata };
export default Page;
