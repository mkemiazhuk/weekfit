import DownloadView from "@/components/pages/DownloadView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("download", "en", DownloadView);
export { metadata };
export default Page;
