import SupportView from "@/components/pages/SupportView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("support", "ru", SupportView);

export const metadata = page.metadata;
export default page.Page;
