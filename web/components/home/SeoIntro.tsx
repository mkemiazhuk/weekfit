"use client";

import clsx from "clsx";
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
  const { t, lang } = useI18n();
  const s = t.seo;

  return (
    <section
      id="about"
      aria-labelledby="about-heading"
      className="relative z-[1] section-x section-y"
    >
      <SectionAmbient tone="morning" />
      <div className="mx-auto max-w-6xl">
        <Reveal>
          <div className="card-panel glass relative overflow-hidden">
            <div
              aria-hidden
              className="pointer-events-none absolute inset-x-0 top-0 h-32"
              style={{
                background:
                  "radial-gradient(70% 100% at 50% 0%, rgba(46,219,250,0.1), transparent 70%)",
              }}
            />

            <div className="relative">
              <div className="md:flex md:items-start md:justify-between md:gap-12">
                <div className="max-w-xl">
                  <p className="kicker text-brand">{s.kicker}</p>
                  <h2
                    id="about-heading"
                    className="display section-title mt-4 text-white"
                  >
                    {s.title}
                  </h2>
                  <p className="body-md section-lead mt-5">{s.p1}</p>
                  <p className="body-sm mt-4 flex items-center gap-2">
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

                <div
                  className="premium-card mt-8 hidden shrink-0 items-center gap-3 surface-chip px-4 py-3 md:mt-1 md:flex"
                  style={{ boxShadow: `0 12px 40px -16px ${pillars.hydration}44` }}
                >
                  <span
                    className="icon-tile"
                    style={{
                      background: `${pillars.hydration}18`,
                      border: `1px solid ${pillars.hydration}33`,
                    }}
                  >
                    <Icon name="health" color={pillars.hydration} size={20} />
                  </span>
                  <div className="min-w-0">
                    <p className="kicker-sm">{s.healthLabel}</p>
                    <p className="mt-0.5 text-[14px] font-semibold text-white/72">
                      {s.healthValue}
                    </p>
                  </div>
                </div>
              </div>

              <div
                aria-hidden
                className="my-8 h-px bg-gradient-to-r from-transparent via-white/[0.1] to-transparent md:my-10"
              />

              <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                {s.features.map((label, i) => {
                  const meta = featureMeta[i];
                  return (
                    <li
                      key={label}
                      className="premium-card surface-chip flex min-h-[88px] min-w-0 flex-col gap-2.5 p-3.5 sm:min-h-0 sm:flex-row sm:items-center sm:gap-3"
                    >
                      <span
                        className="icon-tile h-9 w-9"
                        style={{
                          background: `${meta.color}16`,
                          border: `1px solid ${meta.color}30`,
                        }}
                      >
                        <Icon name={meta.icon} color={meta.color} size={17} />
                      </span>
                      <span
                        className={clsx(
                          "min-w-0 flex-1 font-medium leading-[1.35] text-white/68 [overflow-wrap:anywhere]",
                          lang === "ru"
                            ? "text-[12px] sm:text-[12.5px]"
                            : "text-[12px] sm:text-[13px]"
                        )}
                      >
                        {label}
                      </span>
                    </li>
                  );
                })}
              </ul>

              <div className="surface-chip mt-4 flex min-w-0 items-center gap-3 px-3.5 py-3 md:hidden">
                <span
                  className="icon-tile h-9 w-9"
                  style={{
                    background: `${pillars.hydration}18`,
                    border: `1px solid ${pillars.hydration}33`,
                  }}
                >
                  <Icon name="health" color={pillars.hydration} size={17} />
                </span>
                <div className="min-w-0">
                  <p className="kicker-sm">{s.healthLabel}</p>
                  <p className="truncate text-[13px] font-semibold text-white/80">
                    {s.healthValue}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
