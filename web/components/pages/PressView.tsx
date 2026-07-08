"use client";

import Image from "next/image";
import { useI18n } from "@/lib/i18n";
import { press, brandColors } from "@/lib/content";
import PageHero from "../PageHero";
import Button from "../Button";
import Reveal from "../Reveal";

const screenshots = [
  { src: "/img/today.jpg", label: "Today" },
  { src: "/img/coach.jpg", label: "Coach" },
  { src: "/img/activity.jpg", label: "Activity" },
  { src: "/img/nutrition.jpg", label: "Nutrition" },
];

export default function PressView() {
  const { lang } = useI18n();
  const c = press[lang];

  return (
    <>
      <PageHero kicker={c.kicker} kickerColor="#f5bf5c" title={c.title} lead={c.lead} />

      <div className="mx-auto max-w-4xl space-y-16 px-6 pb-32">
        {/* Icon + quick facts */}
        <Reveal>
          <div className="grid items-center gap-8 rounded-[26px] glass p-8 md:grid-cols-[auto_1fr]">
            <Image
              src="/brand/icon-512.png"
              alt="WeekFit app icon"
              width={128}
              height={128}
              className="rounded-[28px]"
            />
            <div>
              <h2 className="text-[13px] font-semibold uppercase tracking-[0.14em] text-white/40">
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
            <h2 className="text-[13px] font-semibold uppercase tracking-[0.14em] text-white/40">
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
            <h2 className="text-[13px] font-semibold uppercase tracking-[0.14em] text-white/40">
              {c.colorsTitle}
            </h2>
            <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-6">
              {brandColors.map((col) => (
                <div key={col.name} className="rounded-[16px] border border-white/[0.08] p-3">
                  <div
                    className="h-14 w-full rounded-[10px]"
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
            <h2 className="text-[13px] font-semibold uppercase tracking-[0.14em] text-white/40">
              {c.assetsTitle}
            </h2>
            <p className="mt-2 text-white/55">{c.assetsNote}</p>
            <div className="mt-5 grid grid-cols-2 gap-4 sm:grid-cols-4">
              <a
                href="/brand/app-icon.png"
                download
                className="group rounded-[18px] border border-white/[0.08] p-4 transition-colors hover:border-white/20"
              >
                <Image src="/brand/icon-192.png" alt="App icon" width={80} height={80} className="mx-auto rounded-[18px]" />
                <p className="mt-3 text-center text-[13px] text-white/70">App icon</p>
              </a>
              {screenshots.map((s) => (
                <a
                  key={s.label}
                  href={s.src}
                  download
                  className="group rounded-[18px] border border-white/[0.08] p-3 transition-colors hover:border-white/20"
                >
                  <div className="relative mx-auto aspect-[9/19.5] w-full overflow-hidden rounded-[12px]">
                    <Image src={s.src} alt={s.label} fill sizes="160px" className="object-cover" />
                  </div>
                  <p className="mt-2 text-center text-[13px] text-white/70">{s.label}</p>
                </a>
              ))}
            </div>
          </section>
        </Reveal>

        {/* Media contact */}
        <Reveal>
          <div className="rounded-[26px] glass p-8 text-center">
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
