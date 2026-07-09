import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";
import { SITE } from "@/lib/site";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = SITE.title;

export default function Image() {
  return renderOgImage({
    kicker: "Your AI coach",
    title: "One clear call for today.",
    subtitle:
      "What to do now, why it matters, and how to adjust.",
  });
}
