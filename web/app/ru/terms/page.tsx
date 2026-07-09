import TermsView from "@/components/pages/TermsView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("terms", "ru", TermsView);

export const metadata = page.metadata;
export default page.Page;
