import BlogView from "@/components/pages/BlogView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("blog", "en", BlogView);
export { metadata };
export default Page;
