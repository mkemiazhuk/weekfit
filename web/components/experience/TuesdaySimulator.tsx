"use client";

import { useMemo, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import clsx from "clsx";
import { easeCalm, durationUI } from "@/lib/motion";
import { useI18n } from "@/lib/i18n";
import {
  resolveSimulator,
  SIMULATOR_PRESETS,
  type SimulatorDecision,
} from "@/lib/simulator";
import CoachAdviceList from "../CoachAdviceList";
import Button from "../Button";
import { SITE } from "@/lib/site";

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
      <div className="mb-2 flex items-baseline justify-between gap-3">
        <span className="text-[13px] font-medium text-white/62">{label}</span>
        <span className="font-rounded text-[14px] font-semibold tabular-nums text-white">
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

function ReadinessRing({ value, accent, label }: { value: number; accent: string; label: string }) {
  return (
    <div className="flex items-center gap-3 md:gap-4">
      <div className="relative h-[68px] w-[68px] shrink-0 md:h-[80px] md:w-[80px]">
        <svg viewBox="0 0 88 88" className="h-full w-full -rotate-90" aria-hidden>
          <circle cx="44" cy="44" r="36" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="6" />
          <circle
            cx="44"
            cy="44"
            r="36"
            fill="none"
            stroke={accent}
            strokeWidth="6"
            strokeLinecap="round"
            strokeDasharray={2 * Math.PI * 36}
            strokeDashoffset={2 * Math.PI * 36 - (value / 100) * 2 * Math.PI * 36}
            className="transition-[stroke-dashoffset] duration-500 ease-out"
          />
        </svg>
        <span className="absolute inset-0 flex items-center justify-center font-rounded text-[17px] font-semibold tabular-nums text-white md:text-[20px]">
          {value}
        </span>
      </div>
      <div>
        <p className="kicker-sm">{label}</p>
      </div>
    </div>
  );
}

const ALL_DECISIONS: SimulatorDecision[] = [
  "peak",
  "push",
  "quality",
  "move",
  "active_recovery",
  "technique",
  "light_move",
  "protect",
  "recover",
  "full_rest",
  "hrv_rebuild",
  "stacked_fatigue",
];

export default function TuesdaySimulator() {
  const { t, lang, localePath } = useI18n();
  const s = t.experience;
  const reduce = useReducedMotion();

  const [sleep, setSleep] = useState(7.2);
  const [hrv, setHrv] = useState(8);
  const [load, setLoad] = useState(48);

  const result = useMemo(() => resolveSimulator({ sleep, hrv, load }), [sleep, hrv, load]);
  const copy = s.decisions[result.decision];
  const categoryLabel = s.categories[result.category];
  const adviceLabels = t.coachAdvice;

  const fmtSleep = (h: number) => {
    const hrs = Math.floor(h);
    const mins = Math.round((h - hrs) * 60);
    return lang === "ru" ? `${hrs}ч ${mins}м` : `${hrs}h ${mins}m`;
  };
  const fmtHrv = (v: number) => `${v > 0 ? "+" : ""}${v}%`;
  const fmtLoad = (v: number) => `${v}%`;

  const applyPreset = (preset: (typeof SIMULATOR_PRESETS)[number]) => {
    setSleep(preset.sleep);
    setHrv(preset.hrv);
    setLoad(preset.load);
  };

  return (
    <>
      <header className="sim-page-header mx-auto max-w-5xl section-x text-center">
        <p className="kicker text-brand">{s.kicker}</p>
        <h1 className="display section-title-lg mt-3 text-white md:mt-4">{s.title}</h1>
        <p className="body-lg section-lead mx-auto mt-4 md:mt-5">{s.lead}</p>
      </header>

      <div className="mx-auto max-w-5xl section-x pb-20 pt-10 md:pb-24 md:pt-12">
        <div className="grid gap-8 lg:grid-cols-[minmax(0,0.95fr)_1.05fr] lg:gap-14">
          <div className="flex flex-col gap-6">
            <p className="kicker text-white/36">{s.setupKicker}</p>

            <div className="flex flex-col gap-6">
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
            </div>

            <div>
              <p className="kicker-sm mb-2">{s.presetsTitle}</p>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-2 xl:grid-cols-3">
                {SIMULATOR_PRESETS.map((preset) => (
                  <button
                    key={preset.id}
                    type="button"
                    onClick={() => applyPreset(preset)}
                    className="sim-preset rounded-full border border-white/[0.09] bg-white/[0.035] px-3 py-1.5 text-left sm:text-center"
                  >
                    {s.presets[preset.id as keyof typeof s.presets]}
                  </button>
                ))}
              </div>
              <p className="body-sm mt-3 max-w-[34ch]">{s.setupNote}</p>
            </div>
          </div>

          <div className="relative">
            <motion.div
              key={result.decision}
              initial={reduce ? false : { opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: durationUI, ease: easeCalm }}
              className="card-panel card-panel-compact glass overflow-hidden"
              style={{ boxShadow: `var(--shadow-accent) ${result.accent}44` }}
            >
              <div
                aria-hidden
                className="pointer-events-none absolute inset-x-0 top-0 h-36"
                style={{
                  background: `radial-gradient(80% 120% at 50% 0%, ${result.accent}22, transparent 70%)`,
                }}
              />
              <div className="relative">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <p className="kicker-sm">{s.resultKicker}</p>
                  <span
                    className="rounded-full px-2.5 py-1 text-[11px] font-medium uppercase tracking-wide"
                    style={{
                      color: result.accent,
                      background: `${result.accent}18`,
                      border: `1px solid ${result.accent}33`,
                    }}
                  >
                    {categoryLabel}
                  </span>
                </div>
                <p
                  className="display mt-2 text-[clamp(1.35rem,4vw,2.5rem)] leading-[1.08]"
                  style={{ color: result.accent }}
                >
                  {copy.headline}
                </p>
                <p className="body-sm mt-1.5 text-white/58">{copy.subline}</p>

                <div className="mt-4 border-t border-white/[0.08] pt-4 md:mt-5 md:pt-5">
                  <ReadinessRing
                    value={result.readiness}
                    accent={result.accent}
                    label={s.readinessLabel}
                  />
                </div>

                <div className="mt-4 border-t border-white/[0.08] pt-4 md:mt-5 md:pt-5">
                  <CoachAdviceList
                    advice={{
                      matters: copy.matters,
                      do: copy.do,
                      avoid: copy.avoid,
                      next: copy.next,
                      why: copy.why,
                    }}
                    labels={adviceLabels}
                    decision
                    compact
                  />
                </div>
              </div>
            </motion.div>

            <div
              className="mt-3 hidden flex-wrap justify-center gap-1.5 md:flex"
              aria-label={`${ALL_DECISIONS.length} outcomes`}
            >
              {ALL_DECISIONS.map((d) => (
                <span
                  key={d}
                  title={s.decisions[d].headline}
                  aria-hidden
                  className={clsx(
                    "h-1.5 rounded-full transition-all duration-500",
                    d === result.decision ? "w-5 opacity-100" : "w-1.5 opacity-20"
                  )}
                  style={{
                    background: d === result.decision ? result.accent : "rgba(255,255,255,0.5)",
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
