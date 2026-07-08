"use client";

import { useI18n } from "@/lib/i18n";
import { download } from "@/lib/content";
import { pillars } from "@/lib/tokens";
import PageHero from "../PageHero";
import PhoneMockup from "../PhoneMockup";
import AppStoreBadge from "../AppStoreBadge";
import Button from "../Button";
import Reveal from "../Reveal";
import { SITE } from "@/lib/site";

export default function DownloadView() {
  const { lang, t } = useI18n();
  const c = download[lang];

  return (
    <>
      <PageHero kicker={c.kicker} title={c.title} lead={c.lead} />

      <div className="mx-auto max-w-5xl px-6 pb-32">
        <div className="grid items-center gap-14 md:grid-cols-2">
          <Reveal>
            <div className="mx-auto w-full max-w-[300px] phone-float">
              <PhoneMockup src="/img/today.jpg" alt="WeekFit Today screen with the day's readiness and rings" glow={pillars.activity} priority />
            </div>
          </Reveal>

          <Reveal delay={0.1}>
            <div>
              <div className="mb-6 flex flex-col gap-2">
                <Button href={SITE.appInstallUrl} external>
                  {t.cta.testflight}
                </Button>
                <span className="text-[12px] uppercase tracking-[0.16em] text-white/40">
                  {t.cta.testflightNote}
                </span>
              </div>
              <AppStoreBadge soon={c.soon} />

              {/* QR */}
              <div className="mt-8 flex items-center gap-4 rounded-[20px] glass p-4">
                <div
                  className="grid h-20 w-20 flex-none place-items-center rounded-[12px] border border-white/10 bg-white/[0.03]"
                  aria-hidden
                >
                  <div
                    className="h-14 w-14 opacity-30"
                    style={{
                      backgroundImage:
                        "linear-gradient(#fff 2px, transparent 2px), linear-gradient(90deg, #fff 2px, transparent 2px)",
                      backgroundSize: "6px 6px",
                    }}
                  />
                </div>
                <p className="text-[13px] leading-relaxed text-white/50">{c.qr}</p>
              </div>

              {/* Requirements */}
              <div className="mt-8">
                <h2 className="text-[13px] font-semibold uppercase tracking-[0.14em] text-white/40">
                  {c.reqTitle}
                </h2>
                <dl className="mt-4 divide-y divide-white/[0.07] rounded-[18px] border border-white/[0.08]">
                  {c.requirements.map((r) => (
                    <div key={r.label} className="flex items-center justify-between px-5 py-3.5">
                      <dt className="text-[14px] text-white/50">{r.label}</dt>
                      <dd className="text-[14px] font-medium text-white">{r.value}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            </div>
          </Reveal>
        </div>
      </div>
    </>
  );
}
