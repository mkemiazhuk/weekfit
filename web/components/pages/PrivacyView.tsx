"use client";

import { useI18n } from "@/lib/i18n";
import { privacy } from "@/lib/content";
import { pillars, accents } from "@/lib/tokens";
import PageHero from "../PageHero";
import DocLayout from "../DocLayout";
import DocArticle from "./DocArticle";
import Reveal from "../Reveal";
import Icon from "../Icon";
import AppleHealthMark from "../AppleHealthMark";

export default function PrivacyView() {
  const { lang } = useI18n();
  const c = privacy[lang];

  const flow = [
    { icon: "health" as const, color: accents.appleHealth, text: c.flow.from, apple: true },
    { icon: "shield" as const, color: pillars.recovery, text: c.flow.on, apple: false },
    { icon: "sparkles" as const, color: pillars.activity, text: c.flow.never, apple: false },
  ];

  return (
    <>
      <PageHero
        kicker={c.kicker}
        kickerColor={pillars.recovery}
        title={c.title}
        lead={c.lead}
      />

      <div className="mx-auto max-w-4xl section-x pb-20">
        <Reveal>
          <p className="kicker mb-6 text-center text-white/42">{c.flowTitle}</p>
          <div className="privacy-flow-grid">
            {flow.map((f, i) => (
              <div key={i} className="privacy-flow-card">
                {f.apple ? (
                  <span className="privacy-flow-card__icon privacy-flow-card__icon--app">
                    <AppleHealthMark size={36} />
                  </span>
                ) : (
                  <span
                    className="privacy-flow-card__icon"
                    style={{ "--accent-color": f.color } as React.CSSProperties}
                  >
                    <Icon name={f.icon} color={f.color} size={22} />
                  </span>
                )}
                <p className="privacy-flow-card__text">{f.text}</p>
              </div>
            ))}
          </div>
        </Reveal>
      </div>

      <p className="privacy-updated mb-10 text-center">{c.updated}</p>

      <DocLayout
        tocTitle={c.tocTitle}
        toc={c.sections.map((s) => ({ id: s.id, label: s.h }))}
      >
        <DocArticle sections={c.sections} />
      </DocLayout>
    </>
  );
}
