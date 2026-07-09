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
import Button from "../Button";
import { SITE } from "@/lib/site";

function ReadinessRing({ value, accent, label }: { value: number; accent: string; label: string }) {
  return (
    <div className="flex items-center gap-2.5">
      <div className="relative h-14 w-14 shrink-0">
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
        <span className="absolute inset-0 flex items-center justify-center font-rounded text-[15px] font-semibold tabular-nums text-white">
          {value}
        </span>
      </div>
      <p className="kicker-sm leading-tight">{label}</p>
    </div>
  );
}

function InteractiveSignalBar({
  label,
  raw,
  insight,
  levelLabel,
  min,
  max,
  step,
  value,
  onChange,
}: {
  label: string;
  raw: string;
  insight: SignalInsight;
  levelLabel: string;
  min: number;
  max: number;
  step: number;
  value: number;
  onChange: (v: number) => void;
}) {
  return (
    <li>
      <div className="mb-1.5 flex items-baseline justify-between gap-3 text-[13px]">
        <span className="text-white/50">{label}</span>
        <div className="flex items-baseline gap-1.5">
          <span className="font-medium tabular-nums text-white/85">{raw}</span>
          <span className="text-[11px] text-white/35">{levelLabel}</span>
        </div>
      </div>
      <div className="relative h-6">
        <div className="pointer-events-none absolute inset-x-0 top-1/2 h-1.5 -translate-y-1/2 overflow-hidden rounded-full bg-white/[0.06]">
          <motion.div
            className="h-full rounded-full bg-white/60"
            initial={false}
            animate={{ width: `${insight.score}%` }}
            transition={{ duration: 0.45, ease: easeCalm }}
          />
        </div>
        <input
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          aria-label={label}
          className="sim-slider sim-slider--bar absolute inset-0 w-full"
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
  const [hrv, setHrv] = useState(-4);
  const [load, setLoad] = useState(48);

  const result = useMemo(() => resolveSimulator({ sleep, hrv, load }), [sleep, hrv, load]);
  const copy = s.decisions[result.decision];
  const categoryLabel = s.categories[result.category];

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
      <header className="mx-auto max-w-lg section-x pt-20 text-center md:max-w-xl md:pt-28">
        <p className="kicker text-brand">{s.kicker}</p>
        <h1 className="display mt-2 text-[clamp(1.65rem,5vw,2.75rem)] text-white">{s.title}</h1>
        <p className="body-sm mx-auto mt-3 max-w-[34ch] text-white/55">{s.lead}</p>
      </header>

      <div className="mx-auto max-w-lg section-x pb-16 pt-6 md:max-w-xl md:pb-20 md:pt-10">
        <motion.div
          key={result.decision}
          initial={reduce ? false : { opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, ease: easeCalm }}
          className="card-panel glass relative overflow-hidden !p-4 md:!p-7"
          style={{ boxShadow: `0 32px 64px -28px ${result.accent}44` }}
        >
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 top-0 h-32"
            style={{
              background: `radial-gradient(80% 120% at 50% 0%, ${result.accent}22, transparent 70%)`,
            }}
          />
          <div className="relative">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="kicker-sm">{s.resultKicker}</p>
                  <span
                    className="rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide"
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
                  className="display mt-1.5 text-[clamp(1.25rem,4vw,2rem)] leading-[1.1]"
                  style={{ color: result.accent }}
                >
                  {copy.headline}
                </p>
                <p className="body-sm mt-1 text-white/60">{copy.subline}</p>
              </div>
              <ReadinessRing value={result.readiness} accent={result.accent} label={s.readinessLabel} />
            </div>

            <div className="mt-4 border-t border-white/[0.08] pt-4">
              <p className="kicker-sm mb-2.5">{s.signalsTitle}</p>
              <ul className="space-y-3">
                <InteractiveSignalBar
                  label={s.signals.sleep}
                  raw={fmtSleep(sleep)}
                  insight={result.sleep}
                  levelLabel={levelLabel(result.sleep.level)}
                  min={4}
                  max={10}
                  step={0.1}
                  value={sleep}
                  onChange={setSleep}
                />
                <InteractiveSignalBar
                  label={s.signals.hrv}
                  raw={fmtHrv(hrv)}
                  insight={result.hrv}
                  levelLabel={levelLabel(result.hrv.level)}
                  min={-15}
                  max={20}
                  step={1}
                  value={hrv}
                  onChange={setHrv}
                />
                <InteractiveSignalBar
                  label={s.signals.load}
                  raw={fmtLoad(load)}
                  insight={result.load}
                  levelLabel={levelLabel(result.load.level)}
                  min={0}
                  max={100}
                  step={1}
                  value={load}
                  onChange={setLoad}
                />
              </ul>
            </div>

            <div className="mt-3 border-t border-white/[0.08] pt-3">
              <p className="kicker-sm mb-2">{s.presetsTitle}</p>
              <div className="-mx-1 flex gap-1.5 overflow-x-auto px-1 pb-0.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
                {SIMULATOR_PRESETS.map((preset) => (
                  <button
                    key={preset.id}
                    type="button"
                    onClick={() => applyPreset(preset)}
                    className="shrink-0 rounded-full border border-white/[0.1] bg-white/[0.04] px-2.5 py-1 text-[12px] text-white/65 transition hover:border-white/20 hover:bg-white/[0.08] hover:text-white"
                  >
                    {s.presets[preset.id as keyof typeof s.presets]}
                  </button>
                ))}
              </div>
            </div>

            <div className="mt-3 border-t border-white/[0.08] pt-3">
              <p className="text-[14px] leading-snug text-white/82">{copy.do}</p>
              <p className="mt-1 text-[12px] leading-snug text-white/45">{copy.next}</p>
            </div>
          </div>
        </motion.div>

        <div
          className="mt-2.5 flex justify-center gap-1"
          aria-label={`${ALL_DECISIONS.length} outcomes`}
        >
          {ALL_DECISIONS.map((d) => (
            <span
              key={d}
              title={s.decisions[d].headline}
              aria-hidden
              className={clsx(
                "h-1 rounded-full transition-all duration-500",
                d === result.decision ? "w-4 opacity-100" : "w-1 opacity-20"
              )}
              style={{
                background: d === result.decision ? result.accent : "rgba(255,255,255,0.5)",
              }}
            />
          ))}
        </div>

        <p className="body-sm mt-4 text-center text-white/35">{s.setupNote}</p>

        <div className="mt-8 flex flex-col items-center gap-3 text-center">
          <Button href={SITE.appInstallUrl} external size="sm">
            {t.cta.testflight}
          </Button>
          <Button href={localePath("/")} variant="ghost" size="sm">
            {s.backHome}
          </Button>
        </div>
      </div>
    </>
  );
}
