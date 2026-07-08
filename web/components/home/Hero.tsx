"use client";

import { motion, useReducedMotion } from "framer-motion";
import { useCallback, useRef } from "react";
import Button from "../Button";
import PhoneMockup from "../PhoneMockup";
import CoachCard from "../CoachCard";
import HeroRings from "./HeroRings";
import { pillars } from "@/lib/tokens";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import SectionAmbient from "../SectionAmbient";

export default function Hero() {
  const { t } = useI18n();
  const reduce = useReducedMotion();
  const phoneRef = useRef<HTMLDivElement>(null);

  const ease = [0.22, 1, 0.36, 1] as const;
  const rise = (delay: number) => ({
    initial: reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 26 },
    animate: { opacity: 1, y: 0 },
    transition: reduce ? { duration: 0 } : { duration: 0.9, ease, delay },
  });

  const onMouseMove = useCallback(
    (e: React.MouseEvent) => {
      if (reduce || !phoneRef.current) return;
      const rect = phoneRef.current.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const dx = (e.clientX - cx) / rect.width;
      const dy = (e.clientY - cy) / rect.height;
      phoneRef.current.style.transform = `perspective(900px) rotateY(${dx * 6}deg) rotateX(${-dy * 5}deg)`;
    },
    [reduce]
  );

  const onMouseLeave = useCallback(() => {
    if (phoneRef.current) {
      phoneRef.current.style.transform =
        "perspective(900px) rotateY(0deg) rotateX(0deg)";
    }
  }, []);

  return (
    <section
      className="relative mx-auto flex min-h-screen max-w-6xl flex-col items-center px-6 pt-32 pb-16 md:grid md:grid-cols-[1.05fr_0.95fr] md:items-center md:gap-10 md:pt-24"
      onMouseMove={onMouseMove}
      onMouseLeave={onMouseLeave}
    >
      <SectionAmbient tone="morning" />

      {/* Copy */}
      <div className="text-center md:text-left">
        <motion.span
          {...rise(0.05)}
          className="inline-flex items-center gap-2 rounded-full border border-white/12 bg-white/[0.04] px-3.5 py-1.5 text-[13px] text-white/70"
        >
          <span
            className="h-1.5 w-1.5 rounded-full"
            style={{
              background: pillars.coach,
              boxShadow: `0 0 8px ${pillars.coach}`,
            }}
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
          className="mx-auto mt-6 max-w-[40ch] text-[clamp(1.05rem,2.2vw,1.22rem)] leading-relaxed text-white/60 md:mx-0"
        >
          {t.hero.lead}
        </motion.p>

        <motion.div
          {...rise(0.4)}
          className="mt-9 flex flex-wrap items-center justify-center gap-3 md:justify-start"
        >
          <Button href={SITE.appInstallUrl} external>
            {t.cta.testflight}
          </Button>
          <Button href="#reasoning" variant="ghost">
            {t.hero.ctaSecondary}
          </Button>
        </motion.div>
      </div>

      {/* Phone composition */}
      <div className="relative mt-16 w-full max-w-[320px] self-center justify-self-center md:mt-0">
        {/* Breathing glow behind phone */}
        <motion.div
          aria-hidden
          className="absolute -inset-[20%] -z-10 rounded-[50%]"
          style={{
            background: `radial-gradient(closest-side, ${pillars.recovery}30, transparent 70%)`,
            filter: "blur(40px)",
          }}
          animate={
            reduce
              ? {}
              : { scale: [1, 1.08, 1], opacity: [0.7, 1, 0.7] }
          }
          transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
        />

        <motion.div
          initial={
            reduce ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 40, scale: 0.96 }
          }
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={reduce ? { duration: 0 } : { duration: 1.1, ease, delay: 0.3 }}
        >
          <div
            ref={phoneRef}
            className="phone-float relative transition-transform duration-300 ease-out will-change-transform"
            style={{ transformStyle: "preserve-3d" }}
          >
            <HeroRings />
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
            title={t.hero.coachTitle}
            body={t.hero.coachBody}
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
