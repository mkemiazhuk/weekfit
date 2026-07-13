"use client";

import { useI18n } from "@/lib/i18n";
import Reveal from "../Reveal";
import SectionAmbient from "../SectionAmbient";

export default function UseCases() {
  const { t, localePath } = useI18n();
  const c = t.useCases;

  return (
    <section aria-labelledby="use-cases-heading" className="relative z-[1] section-x section-y">
      <SectionAmbient tone="activity" />
      <div className="mx-auto max-w-6xl">
        <Reveal>
          <div className="mb-10 max-w-2xl">
            <p className="kicker text-brand">{c.kicker}</p>
            <h2 id="use-cases-heading" className="display section-title mt-4 text-white">
              {c.title}
            </h2>
            <p className="body-md section-lead mt-5">{c.lead}</p>
          </div>
        </Reveal>

        <div className="grid gap-4 md:grid-cols-3">
          {c.cards.map((card, i) => (
            <Reveal key={card.href} delay={0.03 * i}>
              <a
                href={localePath(card.href)}
                className="card-panel glass group block p-6 transition-colors hover:border-white/[0.16]"
              >
                <p className="text-[16px] font-semibold text-white">{card.title}</p>
                <p className="mt-2 text-[14px] leading-relaxed text-white/60">{card.desc}</p>
                <p className="mt-4 text-[13px] font-semibold text-white/70">
                  {c.cta} →
                </p>
              </a>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

