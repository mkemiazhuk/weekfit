import PressView from "@/components/pages/PressView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("press", "en", PressView);
export { metadata };
export default Page;
