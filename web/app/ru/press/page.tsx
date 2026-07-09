import PressView from "@/components/pages/PressView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("press", "ru", PressView);

export const metadata = page.metadata;
export default page.Page;
