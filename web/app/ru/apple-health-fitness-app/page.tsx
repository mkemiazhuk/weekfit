import AppleHealthFitnessAppView from "@/components/pages/AppleHealthFitnessAppView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("apple-health-fitness-app", "ru", AppleHealthFitnessAppView);

export { metadata };
export default Page;

