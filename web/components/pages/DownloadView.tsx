"use client";

import { useI18n } from "@/lib/i18n";
import { download } from "@/lib/content";
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

      <div className="mx-auto max-w-5xl section-x page-pb">
        <div className="grid items-center gap-16 md:grid-cols-2">
          <Reveal>
            <div className="mx-auto w-full max-w-[300px] phone-float">
              <PhoneMockup
                src="/img/today.jpg"
                alt="WeekFit Today screen with the day's readiness and rings"
                priority
                depth
                width={300}
              />
            </div>
          </Reveal>

          <Reveal delay={0.1}>
            <div>
              <div className="mb-8 flex flex-col gap-2">
                <Button href={SITE.appInstallUrl} external>
                  {t.cta.testflight}
                </Button>
                <span className="caption">{t.cta.testflightNote}</span>
              </div>
              <AppStoreBadge soon={c.soon} footnote={t.cta.appStoreFootnote} />

              <div className="mt-10">
                <h2 className="kicker text-white/40">{c.reqTitle}</h2>
                <dl className="card mt-4 divide-y divide-white/[0.07] overflow-hidden border border-white/[0.08]">
                  {c.requirements.map((r) => (
                    <div key={r.label} className="flex items-center justify-between px-5 py-3.5">
                      <dt className="body-sm">{r.label}</dt>
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
