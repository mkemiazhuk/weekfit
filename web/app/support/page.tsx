import SupportView from "@/components/pages/SupportView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("support", "en", SupportView);
export { metadata };
export default Page;
