import type { Metadata } from "next";
import PressView from "@/components/pages/PressView";

export const metadata: Metadata = {
  title: "Press Kit",
  description:
    "WeekFit press kit — brand assets, boilerplate, colors, screenshots and media contact.",
};

export default function Page() {
  return <PressView />;
}
