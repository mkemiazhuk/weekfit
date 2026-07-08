"use client";

import { motion, useReducedMotion } from "framer-motion";
import Button from "../Button";
import PhoneMockup from "../PhoneMockup";
import CoachCard from "../CoachCard";
import { pillars } from "@/lib/tokens";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";

export default function Hero() {
  const { t } = useI18n();
  const reduce = useReducedMotion();

  const ease = [0.22, 1, 0.36, 1] as const;
  const rise = (delay: number) => ({
    initial: reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 26 },
    animate: { opacity: 1, y: 0 },
    transition: reduce ? { duration: 0 } : { duration: 0.9, ease, delay },
  });

  return (
    <section className="relative mx-auto flex min-h-screen max-w-6xl flex-col items-center px-6 pt-32 pb-16 md:grid md:grid-cols-[1.05fr_0.95fr] md:items-center md:gap-10 md:pt-24">
      {/* Copy */}
      <div className="text-center md:text-left">
        <motion.span
          {...rise(0.05)}
          className="inline-flex items-center gap-2 rounded-full border border-white/12 bg-white/[0.04] px-3.5 py-1.5 text-[13px] text-white/70"
        >
          <span
            className="h-1.5 w-1.5 rounded-full"
            style={{ background: pillars.activity, boxShadow: `0 0 8px ${pillars.activity}` }}
          />
          {t.hero.eyebrow}
        </motion.span>

        <h1 className="display mt-6 text-[clamp(2.8rem,8vw,5.2rem)] text-white">
          <motion.span {...rise(0.12)} className="block">
            {t.hero.titleA}
          </motion.span>
          <motion.span
            {...rise(0.2)}
            className="block"
            style={{
              background: "linear-gradient(100deg, #66f070, #2edbfa)",
              WebkitBackgroundClip: "text",
              backgroundClip: "text",
              WebkitTextFillColor: "transparent",
            }}
          >
            {t.hero.titleB}
          </motion.span>
        </h1>

        <motion.p
          {...rise(0.3)}
          className="mx-auto mt-6 max-w-[46ch] text-[clamp(1.05rem,2.2vw,1.28rem)] leading-relaxed text-white/60 md:mx-0"
        >
          {t.hero.lead}
        </motion.p>

        <motion.div
          {...rise(0.4)}
          className="mt-9 flex flex-wrap items-center justify-center gap-3 md:justify-start"
        >
          <Button href={SITE.testflightUrl} external>
            {t.cta.testflight}
          </Button>
          <Button href="#experience" variant="ghost">
            {t.hero.ctaSecondary}
          </Button>
        </motion.div>
      </div>

      {/* Phone composition */}
      <div className="relative mt-16 w-full max-w-[320px] self-center justify-self-center md:mt-0">
        <motion.div
          initial={reduce ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 40, scale: 0.96 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={reduce ? { duration: 0 } : { duration: 1.1, ease, delay: 0.3 }}
        >
          <div className="phone-float">
            <PhoneMockup
              src="/img/today.jpg"
              alt="WeekFit Today screen showing recovery, activity and nutrition rings"
              glow={pillars.recovery}
              priority
            />
          </div>
        </motion.div>

        {/* Floating coach card */}
        <motion.div
          initial={reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={reduce ? { duration: 0 } : { duration: 0.9, ease, delay: 1.15 }}
          className="absolute -bottom-6 -right-2 w-[220px] sm:-right-8 sm:w-[248px]"
        >
          <CoachCard
            accent={pillars.coach}
            state="Ready"
            title={t.morning.title}
            body={t.morning.body}
            floating
          />
        </motion.div>
      </div>

      {/* Scroll hint */}
      <motion.div
        initial={reduce ? { opacity: 1 } : { opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={reduce ? { duration: 0 } : { duration: 1, delay: 1.6 }}
        className="pointer-events-none absolute bottom-6 left-1/2 -translate-x-1/2 text-center"
      >
        <span className="text-[12px] uppercase tracking-[0.2em] text-white/35">
          {t.hero.scroll}
        </span>
      </motion.div>
    </section>
  );
}
