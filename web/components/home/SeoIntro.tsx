"use client";

import { useI18n } from "@/lib/i18n";
import Reveal from "../Reveal";

export default function SeoIntro() {
  const { t } = useI18n();
  const s = t.seo;

  return (
    <section
      id="about"
      aria-labelledby="about-heading"
      className="relative mx-auto max-w-6xl px-6 pt-20 pb-14 md:pt-28 md:pb-16"
    >
      <div className="grid gap-10 md:grid-cols-[0.9fr_1.1fr] md:gap-16">
        <Reveal>
          <p className="text-[13px] font-semibold uppercase tracking-[0.16em] text-brand">
            {s.kicker}
          </p>
          <h2
            id="about-heading"
            className="mt-5 text-[clamp(1.9rem,3.6vw,2.7rem)] font-semibold leading-[1.1] tracking-[-0.02em] text-white"
          >
            {s.title}
          </h2>
        </Reveal>

        <Reveal delay={0.08}>
          <div className="space-y-5 text-[clamp(1rem,1.5vw,1.12rem)] leading-relaxed text-white/60">
            <p>{s.p1}</p>
            <p>{s.p2}</p>
          </div>

          <ul className="mt-8 flex flex-wrap gap-2.5">
            {s.features.map((f) => (
              <li
                key={f}
                className="rounded-full border border-white/[0.1] bg-white/[0.04] px-3.5 py-1.5 text-[13px] text-white/70"
              >
                {f}
              </li>
            ))}
          </ul>
        </Reveal>
      </div>
    </section>
  );
}
