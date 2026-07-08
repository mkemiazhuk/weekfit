import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Press Kit";

export default function Image() {
  return renderOgImage({
    kicker: "Press Kit",
    title: "WeekFit for press.",
    subtitle: "Brand assets, boilerplate and facts for stories about WeekFit.",
  });
}
