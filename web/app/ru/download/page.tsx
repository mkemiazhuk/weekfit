import DownloadView from "@/components/pages/DownloadView";
import { buildSitePage } from "@/lib/site-page-shell";

const page = buildSitePage("download", "ru", DownloadView);

export const metadata = page.metadata;
export default page.Page;
