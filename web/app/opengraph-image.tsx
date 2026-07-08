import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — A calm AI coach that understands your day";

export default function Image() {
  return renderOgImage({
    kicker: "AI fitness coach",
    title: "Your day, understood.",
    subtitle:
      "WeekFit reads your sleep, recovery, activity and nutrition from Apple Health — and tells you the one thing that matters today.",
  });
}
