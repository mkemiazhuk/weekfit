import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Blog";

export default function Image() {
  return renderOgImage({
    kicker: "Blog",
    title: "Guides & insights.",
    subtitle:
      "Recovery, sleep, nutrition and training — and how a daily AI coach helps you act on them.",
  });
}
