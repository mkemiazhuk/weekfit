import PrivacyView from "@/components/pages/PrivacyView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("privacy", "ru", PrivacyView);

export const metadata = page.metadata;
export default page.Page;
