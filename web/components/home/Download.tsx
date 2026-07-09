"use client";

import { motion, useReducedMotion } from "framer-motion";
import Reveal from "../Reveal";
import PhoneMockup from "../PhoneMockup";
import Button from "../Button";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import SectionAmbient from "../SectionAmbient";

export default function Download() {
  const { t } = useI18n();
  const reduce = useReducedMotion();

  return (
    <section id="download" className="relative z-[1] section-x section-y-lg">
      <SectionAmbient tone="morning" />
      <div className="mx-auto max-w-5xl">
        <Reveal>
          <div className="card-panel relative overflow-hidden glass">
            <motion.div
              aria-hidden
              className="pointer-events-none absolute inset-x-0 top-0 h-64"
              style={{
                background:
                  "radial-gradient(60% 120% at 50% 0%, rgba(46,219,250,0.12), transparent 60%)",
              }}
              animate={reduce ? {} : { opacity: [0.8, 1, 0.8] }}
              transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
            />
            <div className="relative grid items-center gap-12 md:grid-cols-[1.2fr_0.8fr] md:gap-16">
              <div className="text-center md:text-left">
                <p className="font-rounded text-[clamp(2.5rem,6vw,4rem)] font-bold leading-none tracking-[-0.03em] text-white/90">
                  {t.cta.title}
                </p>
                <h2 className="display mt-2 text-[clamp(2rem,5vw,3.4rem)] text-gradient-hero">
                  {t.cta.subtitle}
                </h2>
                <p className="caption mt-6">{t.cta.body}</p>
                <div className="mt-10 flex flex-col items-center gap-2 md:items-start">
                  <Button href={SITE.appInstallUrl} external className="min-w-[220px]">
                    {t.cta.testflight}
                  </Button>
                  <span className="caption">{t.cta.testflightNote}</span>
                </div>
              </div>

              <div className="mx-auto w-full max-w-[220px] phone-float md:max-w-[260px]">
                <PhoneMockup
                  src="/img/today.jpg"
                  alt="WeekFit Today screen with the morning decision"
                />
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
