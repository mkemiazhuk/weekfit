"use client";

import { motion, useReducedMotion } from "framer-motion";
import Reveal from "../Reveal";
import PhoneMockup from "../PhoneMockup";
import AppStoreBadge from "../AppStoreBadge";
import Button from "../Button";
import { pillars } from "@/lib/tokens";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import SectionAmbient from "../SectionAmbient";

export default function Download() {
  const { t } = useI18n();
  const reduce = useReducedMotion();

  return (
    <section id="download" className="relative z-[1] px-5 py-24 md:px-6 md:py-36">
      <SectionAmbient tone="morning" />
      <div className="mx-auto max-w-5xl">
        <Reveal>
          <div className="relative overflow-hidden rounded-[28px] glass px-6 py-12 md:rounded-[34px] md:px-16 md:py-20">
            <motion.div
              aria-hidden
              className="pointer-events-none absolute inset-x-0 top-0 h-64"
              style={{
                background:
                  "radial-gradient(60% 120% at 50% 0%, rgba(102,240,112,0.14), transparent 60%)",
              }}
              animate={reduce ? {} : { opacity: [0.8, 1, 0.8] }}
              transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
            />
            <div className="relative grid items-center gap-10 md:grid-cols-[1.2fr_0.8fr] md:gap-12">
              <div className="text-center md:text-left">
                <h2 className="display text-[clamp(2rem,5vw,3.6rem)] text-white">
                  {t.cta.title}
                </h2>
                <p className="mx-auto mt-4 max-w-[36ch] text-[clamp(1.1rem,2vw,1.35rem)] leading-snug text-white/70 md:mx-0">
                  {t.cta.subtitle}
                </p>
                <p className="mx-auto mt-3 max-w-[40ch] text-[14px] text-white/45 md:mx-0">
                  {t.cta.body}
                </p>
                <div className="mt-8 flex flex-col items-center gap-5 md:items-start">
                  <div className="flex flex-col items-center gap-2 md:items-start">
                    <Button href={SITE.appInstallUrl} external className="min-w-[200px]">
                      {t.cta.testflight}
                    </Button>
                    <span className="text-[11px] uppercase tracking-[0.16em] text-white/40">
                      {t.cta.testflightNote}
                    </span>
                  </div>
                  <AppStoreBadge soon={t.cta.soon} />
                </div>
              </div>

              <div className="mx-auto w-full max-w-[190px] phone-float md:max-w-[220px]">
                <PhoneMockup
                  src="/img/today.jpg"
                  alt="WeekFit Today screen with the day's readiness and rings"
                  glow={pillars.activity}
                />
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
