import ContactView from "@/components/pages/ContactView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("contact", "ru", ContactView);

export const metadata = page.metadata;
export default page.Page;
