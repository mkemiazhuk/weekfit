import ExperienceView from "@/components/pages/ExperienceView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("experience", "ru", ExperienceView);

export { metadata };
export default Page;
