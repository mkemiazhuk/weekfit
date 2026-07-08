import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Changelog";

export default function Image() {
  return renderOgImage({
    kicker: "Changelog",
    title: "What's new.",
    subtitle: "The story of WeekFit, one release at a time.",
  });
}
