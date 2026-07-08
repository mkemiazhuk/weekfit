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
    <section id="download" className="relative px-5 py-20 md:px-6 md:py-40">
      <div className="mx-auto max-w-5xl">
        <Reveal>
          <div className="relative overflow-hidden rounded-[28px] glass px-6 py-10 md:rounded-[34px] md:px-16 md:py-20">
            {/* atmosphere bloom */}
            <div
              aria-hidden
              className="pointer-events-none absolute inset-x-0 top-0 h-64"
              style={{
                background:
                  "radial-gradient(60% 120% at 50% 0%, rgba(102,240,112,0.14), transparent 60%)",
              }}
            />
            <div className="relative grid items-center gap-10 md:grid-cols-[1.2fr_0.8fr] md:gap-12">
              <div className="text-center md:text-left">
                <h2 className="display text-[clamp(1.85rem,5vw,3.6rem)] text-white">
                  {t.cta.title}
                </h2>
                <p className="mx-auto mt-4 max-w-[42ch] text-[15px] leading-relaxed text-white/60 md:mt-5 md:text-[clamp(1.05rem,2vw,1.2rem)] md:mx-0">
                  {t.cta.body}
                </p>
                <div className="mt-7 flex flex-col items-center gap-5 md:mt-9 md:items-start md:gap-6">
                  <div className="flex flex-col items-center gap-2 md:items-start">
                    <Button href={SITE.appInstallUrl} external>
                      {t.cta.testflight}
                    </Button>
                    <span className="text-[12px] uppercase tracking-[0.16em] text-white/40">
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
