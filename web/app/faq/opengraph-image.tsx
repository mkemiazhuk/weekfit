import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Frequently asked questions";

export default function Image() {
  return renderOgImage({
    kicker: "FAQ",
    title: "Frequently asked.",
    subtitle:
      "How the AI coach, recovery score, Apple Health and planning work in WeekFit.",
  });
}
