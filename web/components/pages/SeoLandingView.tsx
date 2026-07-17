"use client";

import { useI18n } from "@/lib/i18n";
import PageHero from "../PageHero";
import Reveal from "../Reveal";
import Button from "../Button";
import { SITE } from "@/lib/site";
import { SEO_LANDINGS, type LandingKey } from "@/lib/seo-landings";

export default function SeoLandingView({ landing }: { landing: LandingKey }) {
  const { lang, t } = useI18n();
  const c = SEO_LANDINGS[landing][lang];

  return (
    <>
      <PageHero kicker={c.kicker} title={c.title} lead={c.lead} />

      <div className="mx-auto max-w-4xl space-y-14 section-x page-pb">
        <Reveal>
          <section className="card-panel glass p-6 md:p-8">
            <h2 className="kicker text-white/40">{c.highlightsTitle}</h2>
            <ul className="mt-4 space-y-2 text-[15px] leading-relaxed text-white/70">
              {c.highlights.map((v) => (
                <li key={v} className="flex gap-2">
                  <span aria-hidden className="mt-[2px] text-brand">
                    •
                  </span>
                  <span>{v}</span>
                </li>
              ))}
            </ul>
          </section>
        </Reveal>

        <Reveal delay={0.05}>
          <section className="card-panel glass p-6 md:p-8">
            <h2 className="kicker text-white/40">{c.whoTitle}</h2>
            <ul className="mt-4 space-y-2 text-[15px] leading-relaxed text-white/70">
              {c.who.map((v) => (
                <li key={v} className="flex gap-2">
                  <span aria-hidden className="mt-[2px] text-brand">
                    •
                  </span>
                  <span>{v}</span>
                </li>
              ))}
            </ul>
          </section>
        </Reveal>

        <Reveal delay={0.1}>
          <section className="card-panel glass p-6 md:p-8">
            <h2 className="kicker text-white/40">{c.faqTitle}</h2>
            <div className="mt-4 space-y-5">
              {c.faqs.map((f) => (
                <div key={f.q}>
                  <p className="text-[15px] font-semibold text-white">{f.q}</p>
                  <p className="mt-1 text-[15px] leading-relaxed text-white/65">{f.a}</p>
                </div>
              ))}
            </div>

            <div className="mt-8 flex flex-col gap-2">
              <Button href={SITE.appInstallUrl} external>
                {t.cta.button}
              </Button>
              <span className="caption">{t.cta.installNote}</span>
            </div>
          </section>
        </Reveal>
      </div>
    </>
  );
}

