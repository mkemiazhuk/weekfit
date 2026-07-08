import FaqView from "@/components/pages/FaqView";
import JsonLd from "@/components/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { allFaqs, breadcrumbSchema, faqSchema } from "@/lib/schema";

const description =
  "Answers to common questions about WeekFit — the AI coach, recovery score, Apple Health integration, nutrition tracking, weekly planning and privacy.";

export const metadata = pageMetadata({
  path: "/faq",
  title: "FAQ",
  description,
  socialTitle: "WeekFit FAQ — AI Coach, Recovery & Apple Health",
  keywords: [
    "WeekFit FAQ",
    "AI fitness coach questions",
    "recovery score explained",
    "Apple Health app help",
  ],
});

export default function Page() {
  return (
    <>
      <JsonLd
        data={[
          faqSchema(allFaqs()),
          breadcrumbSchema([
            { name: "Home", path: "/" },
            { name: "FAQ", path: "/faq" },
          ]),
        ]}
      />
      <FaqView />
    </>
  );
}
