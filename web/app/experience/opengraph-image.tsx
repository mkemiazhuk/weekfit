import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Tuesday Simulator";

export default function Image() {
  return renderOgImage({
    kicker: "Try it",
    title: "See your morning decision.",
    subtitle: "Adjust sleep, HRV and load — watch the coach respond in real time.",
  });
}
