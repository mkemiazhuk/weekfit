"use client";

import { motion, useReducedMotion } from "framer-motion";
import Button from "../Button";
import PhoneMockup from "../PhoneMockup";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeCalm } from "@/lib/motion";
import { pillars } from "@/lib/tokens";

export default function Download() {
  const { t } = useI18n();
  const reduce = useReducedMotion();

  const copy = (delay: number, y = 22) =>
    reduce
      ? {}
      : {
          initial: { opacity: 0, y },
          whileInView: { opacity: 1, y: 0 },
          viewport: { once: true, margin: "-8%" },
          transition: { duration: 0.95, ease: easeCalm, delay },
        };

  const phone = reduce
    ? {}
    : {
        initial: { opacity: 0, y: 48, scale: 0.94 },
        whileInView: { opacity: 1, y: 0, scale: 1 },
        viewport: { once: true, margin: "-10%" },
        transition: { duration: 1.15, ease: easeCalm, delay: 0.58 },
      };

  return (
    <section id="download" className="download-hero section-x section-y-lg section-y-lg-bottom-tight">
      <div className="download-hero__backdrop" aria-hidden>
        <motion.div
          className="download-hero__orb download-hero__orb--cyan"
          animate={reduce ? {} : { x: [0, 12, 0], y: [0, -8, 0], scale: [1, 1.06, 1] }}
          transition={{ duration: 14, repeat: Infinity, ease: "easeInOut" }}
        />
        <motion.div
          className="download-hero__orb download-hero__orb--violet"
          animate={reduce ? {} : { x: [0, -16, 0], y: [0, 10, 0], scale: [1.04, 1, 1.04] }}
          transition={{ duration: 18, repeat: Infinity, ease: "easeInOut", delay: 2 }}
        />
        <motion.div
          className="download-hero__orb download-hero__orb--green"
          animate={reduce ? {} : { opacity: [0.35, 0.55, 0.35] }}
          transition={{ duration: 10, repeat: Infinity, ease: "easeInOut" }}
        />
        <div className="download-hero__noise" />
      </div>

      <div className="download-hero__stage mx-auto max-w-5xl">
        <div className="download-hero__panel">
          <div className="download-hero__grid">
            <div className="download-hero__copy text-center md:text-left">
              <motion.h2
                {...copy(0, 18)}
                className="font-rounded text-[clamp(2.35rem,5.5vw,3.75rem)] font-bold leading-[0.98] tracking-[-0.035em] text-white/92"
              >
                {t.cta.title}
              </motion.h2>
              <motion.p
                {...copy(0.12, 20)}
                className="display section-title-lg text-balance mt-2 text-gradient-hero"
              >
                {t.cta.subtitle}
              </motion.p>
              <motion.p {...copy(0.24, 16)} className="caption mt-6 max-w-[36ch] mx-auto md:mx-0">
                {t.cta.body}
              </motion.p>
              <motion.div
                {...copy(0.38, 14)}
                className="mt-10 flex flex-col items-center gap-2 md:items-start"
              >
                <Button href={SITE.appInstallUrl} external className="btn-premium-glass min-w-[220px]">
                  {t.cta.testflight}
                </Button>
                <span className="caption">{t.cta.testflightNote}</span>
              </motion.div>
            </div>

            <motion.div {...phone} className="download-hero__device">
              <div className="download-hero-phone">
                <motion.div
                  aria-hidden
                  className="download-hero-phone__glow download-hero-phone__glow--recovery"
                  animate={reduce ? {} : { opacity: [0.5, 0.85, 0.5], scale: [1, 1.08, 1] }}
                  transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
                />
                <div className="phone-float">
                  <PhoneMockup
                    src="/img/today.jpg"
                    alt="WeekFit Today screen with the morning decision"
                    glow={pillars.recovery}
                  />
                </div>
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  );
}
