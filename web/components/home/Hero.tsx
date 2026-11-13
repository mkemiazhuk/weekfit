"use client";

import { motion, useReducedMotion } from "framer-motion";
import Button from "../Button";
import HeroDeviceShowcase from "../HeroDeviceShowcase";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeReveal, durationRevealSlow } from "@/lib/motion";
import SectionAmbient from "../SectionAmbient";

const pointTones = [
  { ink: "#4A3D78", wash: "#F0ECF6" },
  { ink: "#8A4E24", wash: "#F8EBE2" },
  { ink: "#386B4D", wash: "#E7F2EB" },
];

export default function Hero() {
  const { t, localePath } = useI18n();
  const reduce = useReducedMotion();

  const fade = (delay: number) => ({
    initial: reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 16 },
    animate: { opacity: 1, y: 0 },
    transition: reduce ? { duration: 0 } : { duration: durationRevealSlow, ease: easeReveal, delay },
  });

  return (
    <section className="hero-polish relative z-0 isolate mx-auto flex max-w-6xl flex-col section-x pb-4 pt-[4.75rem] max-md:min-h-0 md:grid md:grid-cols-[minmax(0,1fr)_292px] md:items-center md:gap-x-10 md:gap-y-5 md:pb-8 md:pt-[5.25rem] lg:gap-x-14">
      <SectionAmbient tone="morning" />

      <div className="relative text-center md:col-start-1 md:row-start-1 md:text-left">
        <h1 className="hero-title display text-[#292b28]">{t.hero.title}</h1>

        <motion.p
          {...fade(0.12)}
          className="hero-lead mx-auto mt-4 max-w-[40rem] text-[1.125rem] leading-snug text-[#3a3d3a] md:mx-0 md:text-[1.25rem]"
        >
          {t.hero.lead}
        </motion.p>

        <motion.div
          {...fade(0.2)}
          className="mx-auto mt-5 flex w-full max-w-md flex-col gap-3 sm:max-w-none sm:flex-row sm:flex-wrap sm:items-center md:mx-0"
        >
          <Button
            href={SITE.appInstallUrl}
            external
            className="btn-hero-primary min-h-[48px] w-full sm:w-auto"
          >
            {t.hero.cta}
          </Button>
          <Button
            href={localePath("/experience")}
            variant="ghost"
            className="btn-hero-glass min-h-[48px] w-full sm:w-auto"
          >
            {t.hero.ctaSecondary}
          </Button>
        </motion.div>

        <p className="mt-4 text-[0.95rem] font-medium text-[#5d5f5c]">{t.hero.health}</p>
      </div>

      <div className="hero-phone relative mx-auto mt-6 w-fit md:col-start-2 md:row-span-2 md:row-start-1 md:mt-0 md:self-center">
        <HeroDeviceShowcase priority />
      </div>

      <motion.ul
        {...fade(0.28)}
        className="mx-auto mt-5 grid w-full gap-2.5 text-left sm:grid-cols-3 md:col-start-1 md:row-start-2 md:mx-0 md:mt-0"
      >
        {t.hero.points.map((point, i) => {
          const tone = pointTones[i] ?? pointTones[0];
          return (
            <li key={point.label} className="rounded-2xl px-3.5 py-3" style={{ background: tone.wash }}>
              <span className="block text-[0.95rem] font-semibold leading-tight" style={{ color: tone.ink }}>
                {point.label}
              </span>
              <span className="mt-1 block text-[0.95rem] leading-snug text-[#292b28]">{point.text}</span>
            </li>
          );
        })}
      </motion.ul>
    </section>
  );
}
