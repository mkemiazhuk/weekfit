"use client";

import Reveal from "../Reveal";
import ProgressRing from "../ProgressRing";
import { pillars } from "@/lib/tokens";
import { useI18n } from "@/lib/i18n";

export default function Pillars() {
  const { t } = useI18n();

  const items = [
    {
      color: pillars.recovery,
      value: 0.81,
      center: "81%",
      name: t.pillars.items.recovery.name,
      desc: t.pillars.items.recovery.desc,
    },
    {
      color: pillars.activity,
      value: 0.65,
      center: "65%",
      name: t.pillars.items.activity.name,
      desc: t.pillars.items.activity.desc,
    },
    {
      color: pillars.nutrition,
      value: 1,
      center: "102%",
      name: t.pillars.items.nutrition.name,
      desc: t.pillars.items.nutrition.desc,
    },
    {
      color: pillars.hydration,
      value: 0.74,
      center: "74%",
      name: t.pillars.items.hydration.name,
      desc: t.pillars.items.hydration.desc,
    },
  ];

  return (
    <section id="pillars" className="relative px-6 py-28 md:py-40">
      <div className="mx-auto max-w-6xl">
        <div className="max-w-3xl">
          <Reveal>
            <span className="text-[13px] font-bold uppercase tracking-[0.18em] text-coach">
              {t.pillars.kicker}
            </span>
          </Reveal>
          <Reveal delay={0.05}>
            <h2 className="display mt-3 text-[clamp(2.2rem,5vw,3.6rem)] text-white">
              {t.pillars.title}
            </h2>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="mt-5 max-w-[54ch] text-[clamp(1.05rem,2vw,1.25rem)] leading-relaxed text-white/55">
              {t.pillars.lead}
            </p>
          </Reveal>
        </div>

        <div className="mt-16 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {items.map((it, i) => (
            <Reveal key={it.name} delay={0.05 * i}>
              <div className="glass h-full rounded-[22px] p-6">
                <ProgressRing
                  value={it.value}
                  color={it.color}
                  size={88}
                  stroke={7}
                  center={it.center}
                />
                <h3 className="mt-6 text-[18px] font-semibold text-white">
                  {it.name}
                </h3>
                <p className="mt-2 text-[14px] leading-relaxed text-white/55">
                  {it.desc}
                </p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
