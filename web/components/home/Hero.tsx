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

  return (
    <section
      className="hero-polish relative z-0 isolate mx-auto flex max-w-6xl flex-col items-center section-x pb-6 pt-[5.75rem] max-md:min-h-0 md:grid md:grid-cols-[0.95fr_1.05fr] md:items-center md:gap-8 md:pb-8 md:pt-28"
    >
      <SectionAmbient tone="morning" />

      <div className="relative text-center md:max-w-[34rem] md:text-left">
        <motion.p {...fade(0.05)} className="hero-time" aria-hidden>
          <HeroLocalTime fallback={t.hero.eyebrow} />
        </motion.p>

        <h1 className="hero-title display text-balance mt-3.5 text-white md:mt-4">
          <span className="block text-white">{t.hero.titleA}</span>
          <span className="text-gradient-hero mt-1 block md:mt-0.5">{t.hero.titleB}</span>
        </h1>

        <motion.p {...fade(0.28)} className="body-lg hero-lead text-balance mx-auto md:mx-0">
          {t.hero.lead}
        </motion.p>

        <motion.div
          {...fade(0.38)}
          className="mt-6 flex flex-wrap items-center justify-center gap-3 md:justify-start"
        >
          <Button href={SITE.appInstallUrl} external className="btn-hero-primary min-h-[44px]">
            {t.cta.button}
          </Button>
          <Button href={localePath("/experience")} variant="ghost" className="btn-hero-glass min-h-[44px]">
            {t.hero.ctaSecondary}
          </Button>
        </motion.div>

        <motion.ul {...fade(0.48)} className="mx-auto mt-6 grid max-w-md gap-2 text-left md:mx-0">
          {t.hero.points.map((point) => (
            <li key={point.label} className="flex items-baseline gap-3 text-[15px] leading-snug text-[#292b28]">
              <span className="w-[5.5rem] shrink-0 font-semibold text-[#386b4d]">{point.label}</span>
              <span className="text-[#3a3d3a]">{point.text}</span>
            </li>
          ))}
        </motion.ul>
      </div>

      <div className="hero-phone relative mt-6 w-full self-center justify-self-center md:mt-0 md:justify-self-end">
        <HeroDeviceShowcase priority />
      </div>

    </section>
  );
}
