"use client";

import { motion, useReducedMotion } from "framer-motion";
import { useCallback, useRef } from "react";
import Button from "../Button";
import PhoneMockup from "../PhoneMockup";
import CoachCard from "../CoachCard";
import { pillars } from "@/lib/tokens";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeCalm } from "@/lib/motion";
import SectionAmbient from "../SectionAmbient";

export default function Hero() {
  const { t, localePath } = useI18n();
  const reduce = useReducedMotion();
  const phoneRef = useRef<HTMLDivElement>(null);

  const rise = (delay: number) => ({
    initial: reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 26 },
    animate: { opacity: 1, y: 0 },
    transition: reduce ? { duration: 0 } : { duration: 0.9, ease: easeCalm, delay },
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
      className="relative z-0 isolate mx-auto flex min-h-screen max-w-6xl flex-col items-center section-x pt-32 pb-28 md:grid md:grid-cols-[1.05fr_0.95fr] md:items-center md:gap-12 md:pb-20 md:pt-24"
      onMouseMove={onMouseMove}
      onMouseLeave={onMouseLeave}
    >
      <SectionAmbient tone="morning" />

      <div className="text-center md:text-left">
        <motion.span {...rise(0.05)} className="eyebrow-pill">
          <span
            className="h-1.5 w-1.5 rounded-full"
            style={{
              background: pillars.coach,
              boxShadow: `0 0 8px ${pillars.coach}`,
            }}
          />
          {t.hero.eyebrow}
        </motion.span>

        <h1 className="display mt-8 text-[clamp(2.8rem,8vw,5.2rem)] text-white">
          <motion.span {...rise(0.12)} className="block">
            {t.hero.titleA}
          </motion.span>
          <motion.span {...rise(0.2)} className="block text-gradient-hero">
            {t.hero.titleB}
          </motion.span>
        </h1>

        <motion.p {...rise(0.3)} className="body-lg mx-auto mt-6 max-w-[38ch] md:mx-0">
          {t.hero.lead}
        </motion.p>

        <motion.div
          {...rise(0.4)}
          className="mt-10 flex flex-wrap items-center justify-center gap-3 md:justify-start"
        >
          <Button href={SITE.appInstallUrl} external>
            {t.cta.testflight}
          </Button>
          <Button href={localePath("/#reasoning")} variant="ghost">
            {t.hero.ctaSecondary}
          </Button>
        </motion.div>
      </div>

      <div className="relative mt-20 w-full max-w-[320px] self-center justify-self-center md:mt-0">
        <motion.div
          aria-hidden
          className="phone-glow"
          style={{
            inset: "-20%",
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
          transition={reduce ? { duration: 0 } : { duration: 1.1, ease: easeCalm, delay: 0.3 }}
        >
          <div
            ref={phoneRef}
            className="relative transition-transform duration-300 ease-out will-change-transform"
            style={{ transformStyle: "preserve-3d" }}
          >
            <div className="phone-float">
              <PhoneMockup
                src="/img/today.jpg"
                alt="WeekFit Today screen showing recovery, activity and nutrition rings"
                priority
              />
            </div>
          </div>
        </motion.div>

        <motion.div
          initial={reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={reduce ? { duration: 0 } : { duration: 0.9, ease: easeCalm, delay: 1.15 }}
          className="absolute -bottom-4 -right-2 hidden w-[220px] md:block sm:-right-8 sm:w-[248px]"
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

      <motion.div
        initial={reduce ? { opacity: 1 } : { opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={reduce ? { duration: 0 } : { duration: 1, delay: 1.6 }}
        className="pointer-events-none absolute bottom-8 left-1/2 -translate-x-1/2 text-center"
      >
        <span className="caption tracking-[0.2em]">{t.hero.scroll}</span>
      </motion.div>
    </section>
  );
}
