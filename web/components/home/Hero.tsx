"use client";

import { motion, useReducedMotion } from "framer-motion";
import { useCallback, useRef } from "react";
import Button from "../Button";
import PhoneMockup from "../PhoneMockup";
import CoachCard from "../CoachCard";
import TextReveal from "../TextReveal";
import { pillars } from "@/lib/tokens";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeCalm } from "@/lib/motion";
import SectionAmbient from "../SectionAmbient";

export default function Hero() {
  const { t, localePath } = useI18n();
  const reduce = useReducedMotion();
  const phoneRef = useRef<HTMLDivElement>(null);

  const fade = (delay: number) => ({
    initial: reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 18 },
    animate: { opacity: 1, y: 0 },
    transition: reduce ? { duration: 0 } : { duration: 0.85, ease: easeCalm, delay },
  });

  const onMouseMove = useCallback(
    (e: React.MouseEvent) => {
      if (reduce || !phoneRef.current) return;
      const rect = phoneRef.current.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const dx = (e.clientX - cx) / rect.width;
      const dy = (e.clientY - cy) / rect.height;
      phoneRef.current.style.transform = `perspective(900px) rotateY(${dx * 5}deg) rotateX(${-dy * 4}deg)`;
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
      className="relative z-0 isolate mx-auto flex min-h-[92vh] max-w-6xl flex-col items-center section-x pt-[7.5rem] pb-24 md:grid md:min-h-screen md:grid-cols-[1fr_0.92fr] md:items-center md:gap-14 md:pb-20 md:pt-28"
      onMouseMove={onMouseMove}
      onMouseLeave={onMouseLeave}
    >
      <SectionAmbient tone="morning" />

      <div className="relative text-center md:max-w-[34rem] md:text-left">
        <motion.p {...fade(0.05)} className="hero-time">
          {t.hero.eyebrow}
        </motion.p>

        <h1 className="display text-balance mt-6 text-[clamp(2.65rem,7.5vw,4.75rem)] leading-[0.96] tracking-[-0.038em] text-white">
          <TextReveal delay={0.1} as="span" className="text-white">
            {t.hero.titleA}
          </TextReveal>
          <TextReveal delay={0.18} as="span" className="text-gradient-hero mt-1 md:mt-0.5">
            {t.hero.titleB}
          </TextReveal>
        </h1>

        <motion.p {...fade(0.32)} className="body-lg text-balance mx-auto mt-7 max-w-[32ch] md:mx-0">
          {t.hero.lead}
        </motion.p>

        <motion.div
          {...fade(0.42)}
          className="mt-11 flex flex-wrap items-center justify-center gap-3 md:justify-start"
        >
          <Button href={SITE.appInstallUrl} external>
            {t.cta.testflight}
          </Button>
          <Button href={localePath("/experience")} variant="ghost">
            {t.hero.ctaSecondary}
          </Button>
        </motion.div>
      </div>

      <div className="relative mt-16 w-full max-w-[300px] self-center justify-self-center md:mt-0 md:max-w-[360px]">
        <motion.div
          aria-hidden
          className="phone-glow"
          style={{
            inset: "-22%",
            background: `radial-gradient(closest-side, ${pillars.recovery}28, transparent 72%)`,
            filter: "blur(44px)",
          }}
          animate={
            reduce ? {} : { scale: [1, 1.06, 1], opacity: [0.65, 1, 0.65] }
          }
          transition={{ duration: 7, repeat: Infinity, ease: "easeInOut" }}
        />

        <motion.div
          initial={
            reduce ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 36, scale: 0.97 }
          }
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={reduce ? { duration: 0 } : { duration: 1.05, ease: easeCalm, delay: 0.28 }}
        >
          <div
            ref={phoneRef}
            className="relative mx-auto transition-transform duration-500 ease-out will-change-transform"
            style={{ transformStyle: "preserve-3d" }}
          >
            <div className="phone-float">
              <PhoneMockup
                src="/img/today.jpg"
                alt="WeekFit Today screen with the morning decision"
                priority
              />
            </div>
          </div>
        </motion.div>

        <motion.div
          initial={reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 22 }}
          animate={{ opacity: 1, y: 0 }}
          transition={reduce ? { duration: 0 } : { duration: 0.9, ease: easeCalm, delay: 0.9 }}
          className="relative z-10 mt-10 w-full md:absolute md:-bottom-8 md:-right-4 md:mt-0 md:w-[252px]"
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

      <motion.a
        href="#reasoning"
        {...fade(1.5)}
        className="scroll-hint group absolute bottom-8 left-1/2 -translate-x-1/2 md:bottom-10"
      >
        <span className="caption block tracking-[0.22em] transition-colors group-hover:text-white/55">
          {t.hero.scroll}
        </span>
        <span aria-hidden className="scroll-hint-line mx-auto mt-3" />
      </motion.a>
    </section>
  );
}
