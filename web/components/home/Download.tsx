"use client";

import { motion, useReducedMotion } from "framer-motion";
import Reveal from "../Reveal";
import PhoneMockup from "../PhoneMockup";
import AppStoreBadge from "../AppStoreBadge";
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
                  "radial-gradient(60% 120% at 50% 0%, rgba(102,240,112,0.14), transparent 60%)",
              }}
              animate={reduce ? {} : { opacity: [0.8, 1, 0.8] }}
              transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
            />
            <div className="relative grid items-center gap-12 md:grid-cols-[1.2fr_0.8fr] md:gap-16">
              <div className="text-center md:text-left">
                <h2 className="display text-[clamp(2rem,5vw,3.6rem)] text-white">
                  {t.cta.title}
                </h2>
                <p className="body-lg mx-auto mt-5 max-w-[32ch] md:mx-0">
                  {t.cta.subtitle}
                </p>
                <div className="mt-10 flex flex-col items-center gap-5 md:items-start">
                  <div className="flex flex-col items-center gap-2 md:items-start">
                    <Button href={SITE.appInstallUrl} external className="min-w-[200px]">
                      {t.cta.testflight}
                    </Button>
                    <span className="caption">{t.cta.testflightNote}</span>
                  </div>
                  <AppStoreBadge soon={t.cta.soon} />
                </div>
              </div>

              <div className="mx-auto w-full max-w-[200px] phone-float md:max-w-[240px]">
                <PhoneMockup
                  src="/img/today.jpg"
                  alt="WeekFit Today screen with the day's readiness and rings"
                />
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
