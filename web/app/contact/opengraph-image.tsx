import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Contact";

export default function Image() {
  return renderOgImage({
    kicker: "Contact",
    title: "We're a message away.",
    subtitle: "Questions, feedback or an issue? We read every email.",
  });
}
