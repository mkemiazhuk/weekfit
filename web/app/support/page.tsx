import type { Metadata } from "next";
import SupportView from "@/components/pages/SupportView";

export const metadata: Metadata = {
  title: "Support",
  description:
    "WeekFit Help Center — setup guides, Apple Health, recovery, nutrition, activities, Coach, planning and troubleshooting.",
};

export default function Page() {
  return <SupportView />;
}
