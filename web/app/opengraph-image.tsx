import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";
import { SITE } from "@/lib/site";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = SITE.title;

export default function Image() {
  return renderOgImage({
    kicker: "AI fitness coach",
    title: "Your day, understood.",
    subtitle:
      "WeekFit reads sleep, recovery, activity and nutrition from Apple Health and tells you what matters today.",
  });
}
