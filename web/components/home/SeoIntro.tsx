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
      className="relative mx-auto max-w-6xl px-6 py-12 md:py-16"
    >
      <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between md:gap-12">
        <Reveal className="max-w-xl">
          <p className="text-[13px] font-semibold uppercase tracking-[0.16em] text-brand">
            {s.kicker}
          </p>
          <h2
            id="about-heading"
            className="mt-4 text-[clamp(1.6rem,3vw,2.2rem)] font-semibold leading-[1.12] tracking-[-0.02em] text-white"
          >
            {s.title}
          </h2>
          <p className="mt-4 text-[15px] leading-relaxed text-white/55 md:text-[16px]">
            {s.p1}
          </p>
        </Reveal>

        <Reveal delay={0.08} className="shrink-0">
          <ul className="flex flex-wrap gap-2 md:max-w-[340px] md:justify-end">
            {s.features.map((f) => (
              <li
                key={f}
                className="rounded-full border border-white/[0.1] bg-white/[0.04] px-3 py-1.5 text-[12px] text-white/65 transition-colors hover:border-white/20 hover:text-white/85"
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
