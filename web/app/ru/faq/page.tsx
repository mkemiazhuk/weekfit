import FaqView from "@/components/pages/FaqView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("faq", "ru", FaqView);

export const metadata = page.metadata;
export default page.Page;
