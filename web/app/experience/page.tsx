import ExperienceView from "@/components/pages/ExperienceView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("experience", "en", ExperienceView);

export { metadata };
export default Page;
