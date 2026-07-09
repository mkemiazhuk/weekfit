import BlogView from "@/components/pages/BlogView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("blog", "ru", BlogView);

export const metadata = page.metadata;
export default page.Page;
