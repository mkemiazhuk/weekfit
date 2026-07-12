import FaqView from "@/components/pages/FaqView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("faq", "en", FaqView);
export { metadata };
export default Page;
