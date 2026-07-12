import ContactView from "@/components/pages/ContactView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("contact", "en", ContactView);
export { metadata };
export default Page;
