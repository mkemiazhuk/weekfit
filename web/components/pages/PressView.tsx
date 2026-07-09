"use client";

import Image from "next/image";
import { useI18n } from "@/lib/i18n";
import { press, brandColors } from "@/lib/content";
import { SITE } from "@/lib/site";
import PageHero from "../PageHero";
import Button from "../Button";
import { accents } from "@/lib/tokens";
import Reveal from "../Reveal";

const screenshots = [
  { src: "/img/today.jpg", label: "Today" },
  { src: "/img/coach.jpg", label: "Coach" },
  { src: "/img/activity.jpg", label: "Activity" },
  { src: "/img/nutrition.jpg", label: "Nutrition" },
  { src: "/img/recovery.jpg", label: "Recovery" },
];

export default function PressView() {
  const { lang } = useI18n();
  const c = press[lang];

  return (
    <>
      <PageHero kicker={c.kicker} kickerColor={accents.gold} title={c.title} lead={c.lead} />

      <div className="mx-auto max-w-4xl space-y-16 section-x page-pb">
        {/* Icon + quick facts */}
        <Reveal>
          <div className="card-panel grid items-center gap-8 glass md:grid-cols-[auto_1fr]">
            <Image
              src="/brand/icon-512.png"
              alt="WeekFit app icon"
              width={128}
              height={128}
              className="rounded-xl"
            />
            <div>
              <h2 className="kicker text-white/40">
                {c.factsTitle}
              </h2>
              <dl className="mt-4 grid grid-cols-2 gap-x-8 gap-y-3 sm:grid-cols-3">
                {c.facts.map((f) => (
                  <div key={f.label}>
                    <dt className="text-[12px] text-white/40">{f.label}</dt>
                    <dd className="text-[15px] text-white">{f.value}</dd>
                  </div>
                ))}
              </dl>
            </div>
          </div>
        </Reveal>

        {/* Boilerplate */}
        <Reveal>
          <section>
            <h2 className="kicker text-white/40">
              {c.boilerTitle}
            </h2>
            <p className="mt-4 text-[18px] font-medium leading-relaxed text-white">
              {c.boilerShort}
            </p>
            <p className="mt-4 leading-relaxed text-white/60">{c.boilerLong}</p>
          </section>
        </Reveal>

        {/* Brand colors */}
        <Reveal>
          <section>
            <h2 className="kicker text-white/40">
              {c.colorsTitle}
            </h2>
            <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-6">
              {brandColors.map((col) => (
                <div key={col.name} className="surface-chip p-3">
                  <div
                    className="h-14 w-full rounded-sm"
                    style={{ background: col.hex, boxShadow: `0 0 24px -6px ${col.hex}` }}
                  />
                  <p className="mt-2 text-[13px] text-white">{col.name}</p>
                  <p className="font-rounded text-[11px] uppercase text-white/40">{col.hex}</p>
                </div>
              ))}
            </div>
          </section>
        </Reveal>

        {/* Assets */}
        <Reveal>
          <section>
            <h2 className="kicker text-white/40">
              {c.assetsTitle}
            </h2>
            <p className="mt-2 text-white/55">{c.assetsNote}</p>
            <div className="mt-5 grid grid-cols-2 gap-4 sm:grid-cols-4">
              <a
                href="/brand/app-icon.png"
                download
                className="group surface-chip p-4 transition-colors hover:border-white/20"
              >
                <Image src="/brand/icon-192.png" alt="App icon" width={80} height={80} className="mx-auto rounded-lg" />
                <p className="mt-3 text-center text-[13px] text-white/70">App icon</p>
              </a>
              {screenshots.map((s) => (
                <a
                  key={s.label}
                  href={s.src}
                  download
                  className="group surface-chip p-3 transition-colors hover:border-white/20"
                >
                  <div className="relative mx-auto aspect-[9/19.5] w-full overflow-hidden rounded-md">
                    <Image src={s.src} alt={s.label} fill sizes="160px" className="object-cover" />
                  </div>
                  <p className="mt-2 text-center text-[13px] text-white/70">{s.label}</p>
                </a>
              ))}
            </div>
          </section>
        </Reveal>

        {/* Google preferred source */}
        <Reveal>
          <div className="card-panel surface-subtle md:p-10">
            <h2 className="kicker text-white/40">
              {c.preferredTitle}
            </h2>
            <p className="mt-4 max-w-[58ch] text-[15px] leading-relaxed text-white/60">
              {c.preferredBody}
            </p>
            <p className="mt-3 max-w-[58ch] text-[14px] leading-relaxed text-white/45">
              {c.preferredNote}
            </p>
            <div className="mt-6 flex flex-col items-start gap-3 sm:flex-row sm:items-center">
              <Button href={SITE.googlePreferredSourceUrl} external variant="ghost">
                {c.preferredCta}
              </Button>
              <code className="rounded-sm border border-white/[0.08] bg-black/30 px-3 py-2 text-[12px] text-white/55">
                {SITE.googlePreferredSourceUrl.replace("https://", "")}
              </code>
            </div>
            <p className="mt-3 text-[12px] text-white/35">{c.preferredLinkLabel}</p>
          </div>
        </Reveal>

        {/* Media contact */}
        <Reveal>
          <div className="card-panel glass text-center">
            <h2 className="text-[20px] font-semibold text-white">{c.contactTitle}</h2>
            <p className="mx-auto mt-2 max-w-[44ch] text-white/60">{c.contactBody}</p>
            <div className="mt-6 flex justify-center">
              <Button href="mailto:support@weekfit.app">support@weekfit.app</Button>
            </div>
          </div>
        </Reveal>
      </div>
    </>
  );
}
