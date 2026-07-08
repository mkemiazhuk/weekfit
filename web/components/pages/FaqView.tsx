"use client";

import { useI18n } from "@/lib/i18n";
import { support } from "@/lib/content";
import PageHero from "../PageHero";
import Icon from "../Icon";
import FAQAccordion from "../FAQAccordion";

export default function FaqView() {
  const { lang } = useI18n();
  const c = support[lang];
  return (
    <>
      <PageHero
        kicker="FAQ"
        kickerColor="#8c66d9"
        title={lang === "ru" ? "Частые вопросы" : "Frequently asked"}
        lead={c.lead}
      />
      <div className="mx-auto max-w-3xl space-y-12 px-6 pb-28">
        {c.categories.map((cat) => (
          <section key={cat.title}>
            <div className="mb-4 flex items-center gap-3">
              <span
                className="flex h-10 w-10 items-center justify-center rounded-[12px]"
                style={{ background: `${cat.color}1f`, border: `1px solid ${cat.color}33` }}
              >
                <Icon name={cat.icon} color={cat.color} size={20} />
              </span>
              <h2 className="text-[18px] font-semibold text-white">{cat.title}</h2>
            </div>
            <FAQAccordion items={cat.faqs} />
          </section>
        ))}
      </div>
    </>
  );
}
