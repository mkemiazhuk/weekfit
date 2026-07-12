import PrivacyView from "@/components/pages/PrivacyView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("privacy", "en", PrivacyView);
export { metadata };
export default Page;
