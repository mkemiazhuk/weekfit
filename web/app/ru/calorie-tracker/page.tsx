import CalorieTrackerView from "@/components/pages/CalorieTrackerView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("calorie-tracker", "ru", CalorieTrackerView);

export { metadata };
export default Page;

