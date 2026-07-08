"use client";

import Reveal from "../Reveal";
import { pillars } from "@/lib/tokens";
import { useI18n } from "@/lib/i18n";

export default function WhyWeekFit() {
  const { t } = useI18n();

  const items = [
    { key: "data", color: pillars.hydration, ...t.why.items.data },
    { key: "matters", color: pillars.activity, ...t.why.items.matters },
    { key: "doing", color: pillars.nutrition, ...t.why.items.doing },
  ];

  return (
    <section id="why" aria-labelledby="why-heading" className="relative px-6 pt-14 pb-28 md:pt-16 md:pb-36">
      <div className="mx-auto max-w-6xl">
        <div className="max-w-[52ch]">
          <Reveal>
            <span className="text-[13px] font-bold uppercase tracking-[0.18em] text-brand">
              {t.why.kicker}
            </span>
          </Reveal>
          <Reveal delay={0.05}>
            <h2
              id="why-heading"
              className="display mt-3 text-[clamp(2.2rem,5vw,3.4rem)] text-white"
            >
              {t.why.title}
            </h2>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="mt-5 text-[clamp(1.05rem,2vw,1.2rem)] leading-relaxed text-white/55">
              {t.why.lead}
            </p>
          </Reveal>
        </div>

        <ol className="mt-14 grid gap-5 md:grid-cols-3">
          {items.map((it, i) => (
            <Reveal key={it.key} delay={0.05 * i}>
              <li className="glass h-full list-none rounded-[22px] p-6">
                <span
                  className="flex h-10 w-10 items-center justify-center rounded-full text-[15px] font-semibold"
                  style={{
                    color: it.color,
                    background: `${it.color}1f`,
                    border: `1px solid ${it.color}33`,
                  }}
                  aria-hidden
                >
                  {i + 1}
                </span>
                <h3 className="mt-5 text-[18px] font-semibold leading-snug text-white">
                  {it.name}
                </h3>
                <p className="mt-2.5 text-[14px] leading-relaxed text-white/55">
                  {it.desc}
                </p>
              </li>
            </Reveal>
          ))}
        </ol>
      </div>
    </section>
  );
}
