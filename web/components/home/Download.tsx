"use client";

import { motion, useReducedMotion } from "framer-motion";
import Button from "../Button";
import PhoneMockup from "../PhoneMockup";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeReveal, durationRevealSlow, durationEntrance } from "@/lib/motion";
import { pillars } from "@/lib/tokens";

export default function Download() {
  const { t } = useI18n();
  const reduce = useReducedMotion();

  const copy = (delay: number, y = 18) =>
    reduce
      ? {}
      : {
          initial: { opacity: 0, y },
          whileInView: { opacity: 1, y: 0 },
          viewport: { once: true, margin: "-8%" },
          transition: { duration: durationRevealSlow, ease: easeReveal, delay },
        };

  const phone = reduce
    ? {}
    : {
        initial: { opacity: 0, y: 36, scale: 0.98 },
        whileInView: { opacity: 1, y: 0, scale: 1 },
        viewport: { once: true, margin: "-10%" },
        transition: { duration: durationEntrance, ease: easeReveal, delay: 0.48 },
      };

  return (
    <section id="download" className="download-hero section-x section-y-lg section-y-lg-bottom-tight">
      <div className="download-hero__backdrop" aria-hidden>
        <div className="download-hero__orb download-hero__orb--cyan" />
        <div className="download-hero__orb download-hero__orb--violet" />
        <div className="download-hero__orb download-hero__orb--green" />
        <div className="download-hero__noise" />
      </div>

      <div className="download-hero__stage mx-auto max-w-5xl">
        <div className="download-hero__panel">
          <div className="download-hero__grid">
            <div className="download-hero__copy min-w-0 text-center md:text-left">
              <motion.h2
                {...copy(0, 16)}
                className="download-hero__title hero-title display min-w-0 text-white/92"
              >
                {t.cta.title}
              </motion.h2>
              <motion.p
                {...copy(0.1, 18)}
                className="display section-title-lg text-balance mt-2 text-gradient-hero"
              >
                {t.cta.subtitle}
              </motion.p>
              <motion.p {...copy(0.2, 14)} className="caption mt-6 max-w-[36ch] mx-auto md:mx-0">
                {t.cta.body}
              </motion.p>
              <motion.div
                {...copy(0.32, 12)}
                className="mt-10 flex flex-col items-center gap-2 md:items-start"
              >
                <Button href={SITE.appInstallUrl} external className="btn-premium-glass min-h-[44px] min-w-[220px]">
                  {t.cta.testflight}
                </Button>
                <span className="caption">{t.cta.testflightNote}</span>
              </motion.div>
            </div>

            <motion.div {...phone} className="download-hero__device">
              <div className="download-hero-phone hero-product-stage">
                <PhoneMockup
                  src="/img/today.jpg"
                  alt="WeekFit Today screen with the morning decision"
                  width={280}
                />
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  );
}
