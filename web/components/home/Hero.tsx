"use client";

import { motion, useReducedMotion } from "framer-motion";
import Button from "../Button";
import HeroDeviceShowcase from "../HeroDeviceShowcase";
import WatchCoachScreen from "../WatchCoachScreen";
import TextReveal from "../TextReveal";
import { pillars } from "@/lib/tokens";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeReveal, durationRevealSlow, durationEntrance } from "@/lib/motion";
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
      className="hero-polish relative z-0 isolate mx-auto flex max-w-6xl flex-col items-center section-x pt-[6.25rem] pb-12 max-md:min-h-0 md:grid md:min-h-[88vh] md:grid-cols-[0.9fr_1.1fr] md:items-center md:gap-10 md:pb-12 md:pt-[6.5rem] lg:gap-12 lg:pb-14"
    >
      <SectionAmbient tone="morning" />

      <div className="relative text-center md:max-w-[34rem] md:text-left">
        <motion.p {...fade(0.05)} className="hero-time" aria-hidden>
          <HeroLocalTime fallback={t.hero.eyebrow} />
        </motion.p>

        <h1 className="hero-title display text-balance mt-3.5 text-white md:mt-4">
          <TextReveal delay={0.1} as="span" className="text-white">
            {t.hero.titleA}
          </TextReveal>
          <TextReveal delay={0.18} as="span" className="text-gradient-hero mt-1 md:mt-0.5">
            {t.hero.titleB}
          </TextReveal>
        </h1>

        <motion.p {...fade(0.28)} className="body-lg hero-lead text-balance mx-auto mt-4 md:mx-0 md:mt-4">
          {t.hero.lead}
        </motion.p>

        <motion.div
          {...fade(0.38)}
          className="mt-7 flex flex-wrap items-center justify-center gap-3 md:mt-8 md:justify-start"
        >
          <Button href={SITE.appInstallUrl} external className="btn-hero-primary min-h-[44px]">
            {t.cta.testflight}
          </Button>
          <Button href={localePath("/experience")} variant="ghost" className="btn-hero-glass min-h-[44px]">
            {t.hero.ctaSecondary}
          </Button>
        </motion.div>
      </div>

      <div className="hero-phone relative mt-6 w-full self-center justify-self-center md:mt-0 md:justify-self-end">
        <motion.div
          initial={
            reduce ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 28, scale: 0.98 }
          }
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={reduce ? { duration: 0 } : { duration: durationEntrance, ease: easeReveal, delay: 0.22 }}
        >
          <HeroDeviceShowcase
            phoneSrc="/img/today.jpg"
            phoneAlt="WeekFit Today screen with the morning decision"
            priority
            watchScreen={
              <WatchCoachScreen
                accent={pillars.coach}
                state="Ready"
                title={t.hero.coachTitle}
                body={t.hero.coachBody}
                coachLabel={t.coachAdvice.label}
              />
            }
          />
        </motion.div>
      </div>

      <motion.a
        href="#reasoning"
        {...fade(1.1)}
        className="scroll-hint group absolute bottom-5 left-1/2 -translate-x-1/2 md:bottom-8"
      >
        <span className="caption block tracking-[0.18em] text-white/28 transition-colors group-hover:text-white/45">
          {t.hero.scroll}
        </span>
        <span aria-hidden className="scroll-hint-line mx-auto mt-3" />
      </motion.a>
    </section>
  );
}
