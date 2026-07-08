"use client";

import Reveal from "../Reveal";
import PhoneMockup from "../PhoneMockup";
import AppStoreBadge from "../AppStoreBadge";
import Button from "../Button";
import { pillars } from "@/lib/tokens";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";

export default function Download() {
  const { t } = useI18n();
  return (
    <section id="download" className="relative px-6 py-28 md:py-40">
      <div className="mx-auto max-w-5xl">
        <Reveal>
          <div className="relative overflow-hidden rounded-[34px] glass px-8 py-14 md:px-16 md:py-20">
            {/* atmosphere bloom */}
            <div
              aria-hidden
              className="pointer-events-none absolute inset-x-0 top-0 h-64"
              style={{
                background:
                  "radial-gradient(60% 120% at 50% 0%, rgba(102,240,112,0.14), transparent 60%)",
              }}
            />
            <div className="relative grid items-center gap-12 md:grid-cols-[1.2fr_0.8fr]">
              <div className="text-center md:text-left">
                <h2 className="display text-[clamp(2.2rem,5vw,3.6rem)] text-white">
                  {t.cta.title}
                </h2>
                <p className="mx-auto mt-5 max-w-[42ch] text-[clamp(1.05rem,2vw,1.2rem)] leading-relaxed text-white/60 md:mx-0">
                  {t.cta.body}
                </p>
                <div className="mt-9 flex flex-col items-center gap-6 md:items-start">
                  <div className="flex flex-col items-center gap-2 md:items-start">
                    <Button href={SITE.testflightUrl} external>
                      {t.cta.testflight}
                    </Button>
                    <span className="text-[12px] uppercase tracking-[0.16em] text-white/40">
                      {t.cta.testflightNote}
                    </span>
                  </div>
                  <AppStoreBadge soon={t.cta.soon} />
                </div>
              </div>

              <div className="mx-auto w-full max-w-[220px] phone-float">
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
