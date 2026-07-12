import TermsView from "@/components/pages/TermsView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("terms", "en", TermsView);
export { metadata };
export default Page;
