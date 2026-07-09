"use client";

import { useMemo, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import clsx from "clsx";
import { pillars } from "@/lib/tokens";
import { easeCalm } from "@/lib/motion";
import { useI18n } from "@/lib/i18n";
import Button from "../Button";
import { SITE } from "@/lib/site";

type Decision = "push" | "hold" | "recover";

function computeDecision(sleep: number, hrv: number, load: number): Decision {
  if (sleep < 6 || hrv < -8) return "recover";
  if (sleep >= 7.5 && hrv >= 5 && load <= 55) return "push";
  if (load >= 75 && hrv < 0) return "recover";
  return "hold";
}

function Slider({
  label,
  value,
  min,
  max,
  step,
  display,
  onChange,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step: number;
  display: string;
  onChange: (v: number) => void;
}) {
  return (
    <label className="block">
      <div className="mb-3 flex items-baseline justify-between gap-3">
        <span className="text-[14px] font-medium text-white/75">{label}</span>
        <span className="font-rounded text-[15px] font-semibold tabular-nums text-white">
          {display}
        </span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="sim-slider w-full"
      />
    </label>
  );
}

export default function TuesdaySimulator() {
  const { t, lang, localePath } = useI18n();
  const s = t.experience;
  const reduce = useReducedMotion();

  const [sleep, setSleep] = useState(7.2);
  const [hrv, setHrv] = useState(8);
  const [load, setLoad] = useState(48);

  const decision = useMemo(() => computeDecision(sleep, hrv, load), [sleep, hrv, load]);
  const copy = s.decisions[decision];
  const accent =
    decision === "push"
      ? pillars.activity
      : decision === "recover"
        ? pillars.recovery
        : pillars.coach;

  const fmtSleep = (h: number) => {
    const hrs = Math.floor(h);
    const mins = Math.round((h - hrs) * 60);
    return lang === "ru" ? `${hrs}ч ${mins}м` : `${hrs}h ${mins}m`;
  };
  const fmtHrv = (v: number) => `${v > 0 ? "+" : ""}${v}%`;
  const fmtLoad = (v: number) => `${v}%`;

  const signals = [
    { label: s.signals.sleep, value: fmtSleep(sleep) },
    { label: s.signals.hrv, value: fmtHrv(hrv) },
    { label: s.signals.load, value: fmtLoad(load) },
  ];

  return (
    <>
      <header className="mx-auto max-w-5xl section-x pt-28 text-center md:pt-32">
        <p className="kicker text-brand">{s.kicker}</p>
        <h1 className="display mt-4 text-[clamp(2.2rem,6vw,3.8rem)] text-white">{s.title}</h1>
        <p className="body-lg mx-auto mt-5 max-w-[42ch]">{s.lead}</p>
      </header>

      <div className="mx-auto max-w-5xl section-x pb-24 pt-10 md:pt-14">
        <div className="grid gap-10 lg:grid-cols-[1fr_1.05fr] lg:gap-14">
          <div className="space-y-8">
            <p className="kicker text-white/40">{s.setupKicker}</p>
            <Slider
              label={s.sleepLabel}
              value={sleep}
              min={4}
              max={10}
              step={0.1}
              display={fmtSleep(sleep)}
              onChange={setSleep}
            />
            <Slider
              label={s.hrvLabel}
              value={hrv}
              min={-15}
              max={20}
              step={1}
              display={fmtHrv(hrv)}
              onChange={setHrv}
            />
            <Slider
              label={s.loadLabel}
              value={load}
              min={0}
              max={100}
              step={1}
              display={fmtLoad(load)}
              onChange={setLoad}
            />
            <p className="body-sm max-w-[36ch]">{s.setupNote}</p>
          </div>

          <div className="relative">
            <motion.div
              key={decision}
              initial={reduce ? false : { opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.45, ease: easeCalm }}
              className="card-panel glass overflow-hidden"
              style={{ boxShadow: `0 40px 80px -32px ${accent}44` }}
            >
              <div
                aria-hidden
                className="pointer-events-none absolute inset-x-0 top-0 h-40"
                style={{
                  background: `radial-gradient(80% 120% at 50% 0%, ${accent}22, transparent 70%)`,
                }}
              />
              <div className="relative">
                <p className="kicker-sm">{s.resultKicker}</p>
                <p
                  className="display mt-3 text-[clamp(2rem,5vw,3rem)] leading-[1.05]"
                  style={{ color: accent }}
                >
                  {copy.headline}
                </p>
                <p className="body-md mt-4">{copy.subline}</p>

                <div className="mt-8 space-y-2 border-t border-white/[0.08] pt-6">
                  <p className="kicker-sm">{s.signalsTitle}</p>
                  <ul className="mt-3 space-y-2">
                    {signals.map((sig) => (
                      <li
                        key={sig.label}
                        className="flex items-center justify-between gap-4 text-[14px]"
                      >
                        <span className="text-white/50">{sig.label}</span>
                        <span className="font-medium tabular-nums text-white/85">{sig.value}</span>
                      </li>
                    ))}
                  </ul>
                </div>

                <p className="body-sm mt-6 border-t border-white/[0.06] pt-5">{copy.reason}</p>
              </div>
            </motion.div>

            <div className="mt-3 flex justify-center gap-2">
              {(["push", "hold", "recover"] as Decision[]).map((d) => (
                <span
                  key={d}
                  aria-hidden
                  className={clsx(
                    "h-1.5 rounded-full transition-all duration-500",
                    d === decision ? "w-8" : "w-1.5",
                    d === decision ? "opacity-100" : "opacity-25"
                  )}
                  style={{
                    background:
                      d === "push"
                        ? pillars.activity
                        : d === "recover"
                          ? pillars.recovery
                          : pillars.coach,
                  }}
                />
              ))}
            </div>
          </div>
        </div>

        <div className="mt-16 flex flex-col items-center gap-4 text-center md:flex-row md:justify-between md:text-left">
          <p className="body-lg max-w-[36ch]">{s.closing}</p>
          <div className="flex flex-wrap items-center justify-center gap-3">
            <Button href={SITE.appInstallUrl} external>
              {t.cta.testflight}
            </Button>
            <Button href={localePath("/")} variant="ghost">
              {s.backHome}
            </Button>
          </div>
        </div>
      </div>
    </>
  );
}
