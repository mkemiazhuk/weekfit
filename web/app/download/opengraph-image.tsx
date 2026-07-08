import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Download for iPhone";

export default function Image() {
  return renderOgImage({
    kicker: "Download",
    title: "Bring calm to your day.",
    subtitle:
      "WeekFit for iPhone. Built around Apple Health, private by design. Free.",
  });
}
