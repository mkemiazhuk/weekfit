import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Terms of Use";

export default function Image() {
  return renderOgImage({
    kicker: "Terms",
    title: "Terms of Use",
    subtitle: "The agreement between you and WeekFit when you use the app.",
  });
}
