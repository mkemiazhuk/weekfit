"use client";

import { motion, useReducedMotion } from "framer-motion";
import Button from "../Button";
import HeroDeviceShowcase from "../HeroDeviceShowcase";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeReveal, durationRevealSlow } from "@/lib/motion";
import SectionAmbient from "../SectionAmbient";
import HeroLocalTime from "./HeroLocalTime";

export default function Hero() {
  const { t, localePath } = useI18n();
  const reduce = useReducedMotion();

  const fade = (delay: number) => ({
    initial: reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 16 },
    animate: { opacity: 1, y: 0 },
    transition: reduce ? { duration: 0 } : { duration: durationRevealSlow, ease: easeReveal, delay },
  });

  const pointTones = [
    { bar: "#EAA06B", ink: "#8A4E24", wash: "#F8EBE2" },
    { bar: "#72AD8A", ink: "#386B4D", wash: "#E7F2EB" },
    { bar: "#9B8ACB", ink: "#4A3D78", wash: "#F0ECF6" },
  ];

  return (
    <section className="hero-polish relative z-0 isolate mx-auto flex max-w-6xl flex-col section-x pb-2 pt-[4.75rem] max-md:min-h-0 md:grid md:grid-cols-[minmax(0,1fr)_292px] md:items-center md:gap-8 md:pb-3 md:pt-[5.25rem] lg:gap-12">
      <SectionAmbient tone="morning" />

      <div className="relative text-center md:text-left">
        <motion.p {...fade(0.05)} className="hero-time" aria-hidden>
          <HeroLocalTime fallback={t.hero.eyebrow} />
        </motion.p>

        <h1 className="hero-title display text-balance mt-2 text-white md:mt-2.5">
          <span className="block text-white">{t.hero.titleA}</span>
          <span className="text-gradient-hero mt-0.5 block">{t.hero.titleB}</span>
        </h1>

        <motion.p {...fade(0.16)} className="hero-lead text-balance mx-auto text-[1.125rem] leading-snug text-[#3a3d3a] md:mx-0 md:text-[1.25rem]">
          {t.hero.lead}
        </motion.p>

        <motion.div
          {...fade(0.24)}
          className="mt-5 flex flex-wrap items-center justify-center gap-3 md:justify-start"
        >
          <Button href={SITE.appInstallUrl} external className="btn-hero-primary min-h-[44px]">
            {t.cta.button}
          </Button>
          <Button href={localePath("/experience")} variant="ghost" className="btn-hero-glass min-h-[44px]">
            {t.hero.ctaSecondary}
          </Button>
        </motion.div>

        <motion.ul {...fade(0.32)} className="mx-auto mt-5 grid gap-2.5 text-left sm:grid-cols-3 md:mx-0">
          {t.hero.points.map((point, i) => {
            const tone = pointTones[i] ?? pointTones[0];
            return (
              <li
                key={point.label}
                className="rounded-2xl px-3.5 py-3"
                style={{ background: tone.wash }}
              >
                <span className="block text-[0.95rem] font-semibold leading-tight" style={{ color: tone.ink }}>
                  {point.label}
                </span>
                <span className="mt-1 block text-[0.95rem] leading-snug text-[#292b28]">{point.text}</span>
              </li>
            );
          })}
        </motion.ul>
      </div>

      <div className="hero-phone relative mx-auto mt-5 w-fit md:mt-0">
        <HeroDeviceShowcase priority />
      </div>
    </section>
  );
}
