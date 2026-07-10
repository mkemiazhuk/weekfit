"use client";

import { useI18n } from "@/lib/i18n";
import { support } from "@/lib/content";
import { pillars } from "@/lib/tokens";
import PageHero from "../PageHero";
import TopicIcon, { topicIconTileClassName, topicIconTileStyle } from "../TopicIcon";
import FAQAccordion from "../FAQAccordion";

export default function FaqView() {
  const { lang, localePath } = useI18n();
  const c = support[lang];
  return (
    <>
      <PageHero
        kicker="FAQ"
        kickerColor={pillars.coach}
        title={lang === "ru" ? "Частые вопросы" : "Frequently asked"}
        lead={c.lead}
      />
      <div className="mx-auto max-w-3xl space-y-12 section-x page-pb">
        {c.categories.map((cat) => (
          <section key={cat.title}>
            <div className="mb-4 flex items-center gap-3">
              <span
                className={topicIconTileClassName(cat.icon)}
                style={topicIconTileStyle(cat.icon, cat.color)}
              >
                <TopicIcon icon={cat.icon} color={cat.color} size={20} />
              </span>
              <h2 className="text-[18px] font-semibold text-white">{cat.title}</h2>
            </div>
            <FAQAccordion items={cat.faqs} />
          </section>
        ))}

        <div className="surface-subtle mt-4 p-6 text-center">
          <p className="text-[15px] text-white/70">
            {lang === "ru"
              ? "Не нашли ответ? В Центре помощи есть подробные руководства."
              : "Didn't find your answer? The Help Center has detailed guides."}
          </p>
          <a
            href={localePath("/support")}
            className="mt-3 inline-block text-[15px] font-semibold text-brand hover:underline"
          >
            {lang === "ru" ? "Перейти в Поддержку →" : "Go to Support →"}
          </a>
        </div>
      </div>
    </>
  );
}
