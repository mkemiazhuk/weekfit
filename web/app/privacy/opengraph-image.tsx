import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Privacy Policy";

export default function Image() {
  return renderOgImage({
    kicker: "Privacy",
    title: "Your health stays yours.",
    subtitle:
      "Local-first and powered by Apple Health. Never uploaded, never sold, never used for advertising.",
  });
}
