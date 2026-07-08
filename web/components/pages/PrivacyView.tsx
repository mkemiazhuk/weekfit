"use client";

import { useI18n } from "@/lib/i18n";
import { privacy } from "@/lib/content";
import { pillars } from "@/lib/tokens";
import PageHero from "../PageHero";
import DocLayout from "../DocLayout";
import DocArticle from "./DocArticle";
import Reveal from "../Reveal";
import Icon from "../Icon";

export default function PrivacyView() {
  const { lang } = useI18n();
  const c = privacy[lang];

  const flow = [
    { icon: "health" as const, color: pillars.nutrition, text: c.flow.from },
    { icon: "shield" as const, color: pillars.recovery, text: c.flow.on },
    { icon: "sparkles" as const, color: pillars.activity, text: c.flow.never },
  ];

  return (
    <>
      <PageHero
        kicker={c.kicker}
        kickerColor={pillars.hydration}
        title={c.title}
        lead={c.lead}
      />

      {/* Visual data-flow */}
      <div className="mx-auto max-w-4xl px-6 pb-20">
        <Reveal>
          <p className="mb-6 text-center text-[13px] font-semibold uppercase tracking-[0.14em] text-white/40">
            {c.flowTitle}
          </p>
          <div className="grid gap-4 md:grid-cols-3">
            {flow.map((f, i) => (
              <div
                key={i}
                className="relative rounded-[22px] glass p-6 text-center"
              >
                <span
                  className="mx-auto flex h-12 w-12 items-center justify-center rounded-[14px]"
                  style={{ background: `${f.color}1f`, border: `1px solid ${f.color}33` }}
                >
                  <Icon name={f.icon} color={f.color} size={24} />
                </span>
                <p className="mt-4 text-[14px] leading-relaxed text-white/70">
                  {f.text}
                </p>
                {i < flow.length - 1 && (
                  <span className="absolute -right-3 top-1/2 hidden -translate-y-1/2 text-white/25 md:block">
                    →
                  </span>
                )}
              </div>
            ))}
          </div>
        </Reveal>
      </div>

      <p className="mb-10 text-center text-[13px] text-white/40">{c.updated}</p>

      <DocLayout
        tocTitle={c.tocTitle}
        toc={c.sections.map((s) => ({ id: s.id, label: s.h }))}
      >
        <DocArticle sections={c.sections} />
      </DocLayout>
    </>
  );
}
