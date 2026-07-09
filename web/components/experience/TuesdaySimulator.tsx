"use client";

import { useMemo, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import clsx from "clsx";
import { easeCalm } from "@/lib/motion";
import { useI18n } from "@/lib/i18n";
import {
  resolveSimulator,
  SIMULATOR_PRESETS,
  type SimulatorDecision,
  type SignalInsight,
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

function ReadinessRing({ value, accent, label }: { value: number; accent: string; label: string }) {
  const r = 36;
  const c = 2 * Math.PI * r;
  const offset = c - (value / 100) * c;

  return (
    <div className="flex items-center gap-4">
      <div className="relative h-[88px] w-[88px] shrink-0">
        <svg viewBox="0 0 88 88" className="h-full w-full -rotate-90" aria-hidden>
          <circle cx="44" cy="44" r={r} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="6" />
          <circle
            cx="44"
            cy="44"
            r={r}
            fill="none"
            stroke={accent}
            strokeWidth="6"
            strokeLinecap="round"
            strokeDasharray={c}
            strokeDashoffset={offset}
            className="transition-[stroke-dashoffset] duration-500 ease-out"
          />
        </svg>
        <span className="absolute inset-0 flex items-center justify-center font-rounded text-[22px] font-semibold tabular-nums text-white">
          {value}
        </span>
      </div>
      <div>
        <p className="kicker-sm">{label}</p>
      </div>
    </div>
  );
}

function SignalBar({
  label,
  raw,
  insight,
  levelLabel,
}: {
  label: string;
  raw: string;
  insight: SignalInsight;
  levelLabel: string;
}) {
  return (
    <li className="space-y-2">
      <div className="flex items-baseline justify-between gap-4 text-[14px]">
        <span className="text-white/50">{label}</span>
        <div className="flex items-baseline gap-2">
          <span className="font-medium tabular-nums text-white/85">{raw}</span>
          <span className="text-[12px] text-white/35">{levelLabel}</span>
        </div>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-white/[0.06]">
        <motion.div
          className="h-full rounded-full bg-white/70"
          initial={false}
          animate={{ width: `${insight.score}%` }}
          transition={{ duration: 0.45, ease: easeCalm }}
        />
      </div>
    </li>
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

  const levelLabel = (level: SignalInsight["level"]) => s.signalLevels[level];

  const applyPreset = (preset: (typeof SIMULATOR_PRESETS)[number]) => {
    setSleep(preset.sleep);
    setHrv(preset.hrv);
    setLoad(preset.load);
  };

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

            <div>
              <p className="kicker-sm mb-3">{s.presetsTitle}</p>
              <div className="flex flex-wrap gap-2">
                {SIMULATOR_PRESETS.map((preset) => (
                  <button
                    key={preset.id}
                    type="button"
                    onClick={() => applyPreset(preset)}
                    className="rounded-full border border-white/[0.1] bg-white/[0.04] px-3 py-1.5 text-[13px] text-white/70 transition hover:border-white/20 hover:bg-white/[0.08] hover:text-white"
                  >
                    {s.presets[preset.id as keyof typeof s.presets]}
                  </button>
                ))}
              </div>
            </div>

            <p className="body-sm max-w-[36ch]">{s.setupNote}</p>
          </div>

          <div className="relative">
            <motion.div
              key={result.decision}
              initial={reduce ? false : { opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.45, ease: easeCalm }}
              className="card-panel glass overflow-hidden"
              style={{ boxShadow: `0 40px 80px -32px ${result.accent}44` }}
            >
              <div
                aria-hidden
                className="pointer-events-none absolute inset-x-0 top-0 h-40"
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
                  className="display mt-3 text-[clamp(2rem,5vw,3rem)] leading-[1.05]"
                  style={{ color: result.accent }}
                >
                  {copy.headline}
                </p>
                <p className="body-md mt-4">{copy.subline}</p>

                <div className="mt-8 border-t border-white/[0.08] pt-6">
                  <ReadinessRing
                    value={result.readiness}
                    accent={result.accent}
                    label={s.readinessLabel}
                  />
                </div>

                <div className="mt-8 space-y-4 border-t border-white/[0.08] pt-6">
                  <p className="kicker-sm">{s.signalsTitle}</p>
                  <ul className="space-y-4">
                    <SignalBar
                      label={s.signals.sleep}
                      raw={fmtSleep(sleep)}
                      insight={result.sleep}
                      levelLabel={levelLabel(result.sleep.level)}
                    />
                    <SignalBar
                      label={s.signals.hrv}
                      raw={fmtHrv(hrv)}
                      insight={result.hrv}
                      levelLabel={levelLabel(result.hrv.level)}
                    />
                    <SignalBar
                      label={s.signals.load}
                      raw={fmtLoad(load)}
                      insight={result.load}
                      levelLabel={levelLabel(result.load.level)}
                    />
                  </ul>
                </div>

                <div className="mt-6 border-t border-white/[0.08] pt-6">
                  <CoachAdviceList
                    advice={{
                      matters: copy.matters,
                      do: copy.do,
                      avoid: copy.avoid,
                      next: copy.next,
                      why: copy.why,
                    }}
                    labels={adviceLabels}
                  />
                </div>
              </div>
            </motion.div>

            <div
              className="mt-4 flex flex-wrap justify-center gap-1.5"
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
