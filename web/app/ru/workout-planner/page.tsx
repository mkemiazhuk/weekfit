import WorkoutPlannerView from "@/components/pages/WorkoutPlannerView";
import { buildSitePage } from "@/lib/site-page-shell";

const { metadata, Page } = buildSitePage("workout-planner", "ru", WorkoutPlannerView);

export { metadata };
export default Page;

