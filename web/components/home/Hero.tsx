"use client";

import type { CSSProperties } from "react";
import Button from "../Button";
import HeroDeviceShowcase from "../HeroDeviceShowcase";
import TextReveal from "../TextReveal";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { useReducedMotion } from "@/lib/use-reduced-motion";
import SectionAmbient from "../SectionAmbient";
import HeroLocalTime from "./HeroLocalTime";

function heroFadeStyle(delay: number, y = 16): CSSProperties | undefined {
  return { animationDelay: `${delay}s`, "--hero-y": `${y}px` } as CSSProperties;
}

export default function Hero() {
  const { t, localePath } = useI18n();
  const reduce = useReducedMotion();

  return (
    <section
      className="hero-polish relative z-0 isolate mx-auto flex max-w-6xl flex-col items-center section-x pt-[6.25rem] pb-12 max-md:min-h-0 md:grid md:min-h-[88vh] md:grid-cols-[0.9fr_1.1fr] md:items-center md:gap-10 md:pb-16 md:pt-[6.5rem] lg:gap-12 lg:pb-[4.5rem]"
    >
      <SectionAmbient tone="morning" />

      <div className="relative text-center md:max-w-[34rem] md:text-left">
        <p
          className={reduce ? "hero-time" : "hero-time motion-hero-fade"}
          style={reduce ? undefined : heroFadeStyle(0.05)}
          aria-hidden
        >
          <HeroLocalTime fallback={t.hero.eyebrow} />
        </p>

        <h1 className="hero-title display text-balance mt-3.5 text-white md:mt-4">
          <TextReveal delay={0.1} as="span" className="text-white">
            {t.hero.titleA}
          </TextReveal>
          <TextReveal delay={0.18} as="span" className="text-gradient-hero mt-1 md:mt-0.5">
            {t.hero.titleB}
          </TextReveal>
        </h1>

        <p
          className={
            reduce
              ? "body-lg hero-lead text-balance mx-auto md:mx-0"
              : "body-lg hero-lead text-balance mx-auto motion-hero-fade md:mx-0"
          }
          style={reduce ? undefined : heroFadeStyle(0.28)}
        >
          {t.hero.lead}
        </p>

        <div
          className={
            reduce
              ? "mt-7 flex flex-wrap items-center justify-center gap-3 md:mt-8 md:justify-start"
              : "mt-7 flex flex-wrap items-center justify-center gap-3 motion-hero-fade md:mt-8 md:justify-start"
          }
          style={reduce ? undefined : heroFadeStyle(0.38)}
        >
          <Button href={SITE.appInstallUrl} external className="btn-hero-primary min-h-[44px]">
            {t.cta.testflight}
          </Button>
          <Button href={localePath("/experience")} variant="ghost" className="btn-hero-glass min-h-[44px]">
            {t.hero.ctaSecondary}
          </Button>
        </div>
      </div>

      <div className="hero-phone relative mt-6 w-full self-center justify-self-center md:mt-0 md:justify-self-end">
        <div
          className={reduce ? undefined : "motion-hero-entrance"}
          style={reduce ? undefined : heroFadeStyle(0.22, 28)}
        >
          <HeroDeviceShowcase priority />
        </div>
      </div>

      <a
        href="#reasoning"
        className={
          reduce
            ? "scroll-hint group absolute bottom-5 left-1/2 -translate-x-1/2 md:bottom-8"
            : "scroll-hint group absolute bottom-5 left-1/2 -translate-x-1/2 motion-hero-fade md:bottom-8"
        }
        style={reduce ? undefined : heroFadeStyle(1.1)}
      >
        <span className="caption block tracking-[0.18em] text-white/28 transition-colors group-hover:text-white/45">
          {t.hero.scroll}
        </span>
        <span aria-hidden className="scroll-hint-line mx-auto mt-3" />
      </a>
    </section>
  );
}
