import { renderOgImage, OG_SIZE, OG_CONTENT_TYPE } from "@/lib/og";

export const dynamic = "force-static";
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;
export const alt = "WeekFit — Help Center";

export default function Image() {
  return renderOgImage({
    kicker: "Help Center",
    title: "How can we help?",
    subtitle:
      "Setup guides and answers for Apple Health, recovery, nutrition, activities and the Coach.",
  });
}
