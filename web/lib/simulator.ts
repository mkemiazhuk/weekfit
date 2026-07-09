import { pillars } from "./tokens";

/** Distinct morning calls — at least 9 unique outcomes from sleep × HRV × load. */
export type SimulatorDecision =
  | "peak"
  | "push"
  | "quality"
  | "move"
  | "active_recovery"
  | "technique"
  | "light_move"
  | "protect"
  | "recover"
  | "full_rest"
  | "hrv_rebuild"
  | "stacked_fatigue";

export type DecisionCategory = "push" | "balance" | "recover";

export interface SimulatorInput {
  sleep: number; // hours 4–10
  hrv: number; // % vs baseline −15…+20
  load: number; // yesterday strain 0–100
}

export interface SignalInsight {
  level: "low" | "ok" | "strong" | "high";
  score: number; // 0–100 for bar display
}

export interface SimulatorResult {
  decision: SimulatorDecision;
  category: DecisionCategory;
  accent: string;
  readiness: number; // 0–100 composite
  sleep: SignalInsight;
  hrv: SignalInsight;
  load: SignalInsight;
}

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}

function sleepScore(h: number): number {
  if (h < 5) return clamp((h - 4) * 35, 0, 35);
  if (h < 7) return clamp(35 + (h - 5) * 22, 35, 79);
  if (h <= 8.5) return clamp(79 + (h - 7) * 14, 79, 100);
  return clamp(100 - (h - 8.5) * 8, 88, 100);
}

function hrvScore(pct: number): number {
  return clamp(50 + pct * 2.4, 0, 100);
}

/** Lower load → higher readiness (yesterday was lighter). */
function loadRecoveryScore(strain: number): number {
  return clamp(100 - strain * 0.92, 0, 100);
}

function levelFromScore(score: number): SignalInsight["level"] {
  if (score >= 72) return "strong";
  if (score >= 48) return "ok";
  if (score >= 28) return "low";
  return "low";
}

function loadLevel(strain: number): SignalInsight["level"] {
  if (strain >= 78) return "high";
  if (strain >= 52) return "ok";
  if (strain >= 28) return "ok";
  return "low";
}

const CATEGORY_ACCENT: Record<DecisionCategory, string> = {
  push: pillars.activity,
  balance: pillars.coach,
  recover: pillars.recovery,
};

/**
 * Priority-ordered rule engine — first match wins.
 * Covers sleep-dominant, HRV-dominant, and load-dominant scenarios.
 */
export function resolveSimulator(input: SimulatorInput): SimulatorResult {
  const { sleep, hrv, load } = input;

  const sSleep = sleepScore(sleep);
  const sHrv = hrvScore(hrv);
  const sLoad = loadRecoveryScore(load);

  const readiness = Math.round(sSleep * 0.38 + sHrv * 0.36 + sLoad * 0.26);

  const signals = {
    sleep: { score: Math.round(sSleep), level: levelFromScore(sSleep) },
    hrv: { score: Math.round(sHrv), level: levelFromScore(sHrv) },
    load: { score: Math.round(100 - load), level: loadLevel(load) },
  };

  let decision: SimulatorDecision;
  let category: DecisionCategory;

  // Critical rest
  if (sleep < 5 || hrv <= -12 || (sleep < 5.5 && load >= 88)) {
    decision = "full_rest";
    category = "recover";
  }
  // Peak window
  else if (sleep >= 7.8 && hrv >= 14 && load <= 32) {
    decision = "peak";
    category = "push";
  }
  // Slept well but autonomic stress
  else if (sleep >= 7 && hrv <= -8) {
    decision = "hrv_rebuild";
    category = "recover";
  }
  // Heavy block + suppressed HRV
  else if (load >= 78 && hrv <= -4) {
    decision = "stacked_fatigue";
    category = "recover";
  }
  // Clear recovery day
  else if (sleep < 6 || hrv <= -9 || (sleep < 6.5 && hrv <= -4 && load >= 55)) {
    decision = "recover";
    category = "recover";
  }
  // Short sleep, nervous system still OK
  else if (sleep < 6.5 && hrv >= 6 && load <= 60) {
    decision = "light_move";
    category = "balance";
  }
  // Muscular fatigue dominates
  else if (load >= 72 && sleep >= 6.2 && hrv >= -6) {
    decision = "technique";
    category = "balance";
  }
  // Moderate strain — active recovery
  else if (load >= 58 && load < 72 && sleep >= 6 && hrv >= -4) {
    decision = "active_recovery";
    category = "balance";
  }
  // Good base but recent hard day — quality not volume
  else if (sleep >= 6.8 && hrv >= 2 && load >= 42 && load < 68) {
    decision = "quality";
    category = "push";
  }
  // Strong green light
  else if (sleep >= 7.4 && hrv >= 7 && load <= 52) {
    decision = "push";
    category = "push";
  }
  // Borderline — protect capacity
  else if (readiness < 42 || (sleep < 6.8 && hrv < 0) || (load >= 65 && hrv < 2)) {
    decision = "protect";
    category = "recover";
  }
  // Default productive day
  else if (sleep >= 6.4 && hrv >= -2 && load <= 68) {
    decision = "move";
    category = "balance";
  }
  else {
    decision = "move";
    category = "balance";
  }

  return {
    decision,
    category,
    accent: CATEGORY_ACCENT[category],
    readiness,
    sleep: signals.sleep,
    hrv: signals.hrv,
    load: signals.load,
  };
}

export const SIMULATOR_PRESETS: { id: string; sleep: number; hrv: number; load: number }[] = [
  { id: "peak", sleep: 8.2, hrv: 16, load: 22 },
  { id: "after_ride", sleep: 7.4, hrv: 9, load: 71 },
  { id: "short_sleep", sleep: 5.4, hrv: 4, load: 38 },
  { id: "hard_week", sleep: 6.8, hrv: -6, load: 82 },
  { id: "rest_day", sleep: 5.2, hrv: -11, load: 64 },
  { id: "travel", sleep: 6.1, hrv: -3, load: 45 },
];
