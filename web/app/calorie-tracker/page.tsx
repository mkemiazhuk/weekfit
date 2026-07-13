import CalorieTrackerView from "@/components/pages/CalorieTrackerView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("calorie-tracker", "en", CalorieTrackerView);

export { metadata };
export default Page;

