"use client";

import { useI18n } from "@/lib/i18n";
import { pillars, accents } from "@/lib/tokens";
import Reveal from "../Reveal";
import SectionAmbient from "../SectionAmbient";
import Icon, { type IconName } from "../Icon";

const featureMeta: { icon: IconName; color: string }[] = [
  { icon: "recovery", color: pillars.recovery },
  { icon: "coach", color: pillars.coach },
  { icon: "nutrition", color: pillars.nutrition },
  { icon: "plan", color: pillars.activity },
  { icon: "health", color: pillars.hydration },
  { icon: "shield", color: accents.brand },
];

export default function SeoIntro() {
  const { t } = useI18n();
  const s = t.seo;

  return (
    <section
      id="about"
      aria-labelledby="about-heading"
      className="relative px-5 py-14 md:px-6 md:py-20"
    >
      <SectionAmbient tone="morning" />
      <div className="mx-auto max-w-6xl">
        <Reveal>
          <div className="glass relative overflow-hidden rounded-[28px] p-6 md:p-10">
            {/* subtle top glow */}
            <div
              aria-hidden
              className="pointer-events-none absolute inset-x-0 top-0 h-32"
              style={{
                background:
                  "radial-gradient(70% 100% at 50% 0%, rgba(46,219,250,0.1), transparent 70%)",
              }}
            />

            <div className="relative">
              {/* Header */}
              <div className="md:flex md:items-start md:justify-between md:gap-10">
                <div className="max-w-xl">
                  <p className="text-[13px] font-bold uppercase tracking-[0.16em] text-brand">
                    {s.kicker}
                  </p>
                  <h2
                    id="about-heading"
                    className="display mt-3 text-[clamp(1.75rem,3.8vw,2.5rem)] text-white"
                  >
                    {s.title}
                  </h2>
                  <p className="mt-4 text-[15px] leading-relaxed text-white/60 md:text-[16px]">
                    {s.p1}
                  </p>
                  <p className="mt-3 flex items-center gap-2 text-[14px] font-medium text-white/45">
                    <svg
                      viewBox="0 0 24 24"
                      className="h-4 w-4 shrink-0 opacity-70"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth={1.8}
                      aria-hidden
                    >
                      <rect x="5" y="11" width="14" height="10" rx="2" />
                      <path d="M8 11V8a4 4 0 1 1 8 0v3" strokeLinecap="round" />
                    </svg>
                    {s.privacy}
                  </p>
                </div>

                {/* Apple Health badge — desktop */}
                <div
                  className="premium-card mt-6 hidden shrink-0 items-center gap-3 rounded-[18px] border border-white/[0.1] bg-white/[0.04] px-4 py-3 md:mt-1 md:flex"
                  style={{
                    boxShadow: `0 12px 40px -16px ${pillars.hydration}44`,
                  }}
                >
                  <span
                    className="flex h-10 w-10 items-center justify-center rounded-[12px]"
                    style={{
                      background: `${pillars.hydration}18`,
                      border: `1px solid ${pillars.hydration}33`,
                    }}
                  >
                    <Icon name="health" color={pillars.hydration} size={20} />
                  </span>
                  <div>
                    <p className="text-[11px] font-bold uppercase tracking-[0.14em] text-white/40">
                      {s.healthLabel}
                    </p>
                    <p className="mt-0.5 text-[14px] font-semibold text-white/85">
                      {s.healthValue}
                    </p>
                  </div>
                </div>
              </div>

              {/* Divider */}
              <div
                aria-hidden
                className="my-7 h-px bg-gradient-to-r from-transparent via-white/[0.1] to-transparent md:my-8"
              />

              {/* Capability grid */}
              <ul className="grid grid-cols-2 gap-2.5 sm:grid-cols-3 sm:gap-3">
                {s.features.map((label, i) => {
                  const meta = featureMeta[i];
                  return (
                    <li
                      key={label}
                      className="premium-card flex items-center gap-3 rounded-[16px] border border-white/[0.08] bg-white/[0.03] px-3 py-3 md:px-3.5 md:py-3.5"
                    >
                      <span
                        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[11px]"
                        style={{
                          background: `${meta.color}16`,
                          border: `1px solid ${meta.color}30`,
                        }}
                      >
                        <Icon name={meta.icon} color={meta.color} size={17} />
                      </span>
                      <span className="text-[13px] font-medium leading-snug text-white/78">
                        {label}
                      </span>
                    </li>
                  );
                })}
              </ul>

              {/* Apple Health badge — mobile */}
              <div className="mt-4 flex items-center gap-3 rounded-[16px] border border-white/[0.08] bg-white/[0.03] px-3.5 py-3 md:hidden">
                <span
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[11px]"
                  style={{
                    background: `${pillars.hydration}18`,
                    border: `1px solid ${pillars.hydration}33`,
                  }}
                >
                  <Icon name="health" color={pillars.hydration} size={17} />
                </span>
                <div>
                  <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-white/40">
                    {s.healthLabel}
                  </p>
                  <p className="text-[13px] font-semibold text-white/80">{s.healthValue}</p>
                </div>
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
