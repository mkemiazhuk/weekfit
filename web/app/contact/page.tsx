import type { Metadata } from "next";
import ContactView from "@/components/pages/ContactView";

export const metadata: Metadata = {
  title: "Contact",
  description: "Get in touch with the WeekFit team.",
};

export default function Page() {
  return <ContactView />;
}
