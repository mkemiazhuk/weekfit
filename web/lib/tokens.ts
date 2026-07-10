// WeekFit design tokens for JS-side use (rings, gradients, atmosphere).
// Extracted from the iOS app's Theme layer.

export const pillars = {
  activity: "#66f070",
  nutrition: "#ff9424",
  recovery: "#2edbfa",
  hydration: "#4088f2",
  coach: "#8c66d9",
} as const;

export const pastels = {
  meal: "#8cd19c",
  workout: "#809eeb",
  recovery: "#ad8fe6",
  habit: "#ed9e57",
} as const;

export const accents = {
  gold: "#f5bf5c",
  brand: "#66bc87",
  appleHealth: "#ff2d55",
} as const;

export type RGB = [number, number, number];

export interface AtmospherePhase {
  key: "morning" | "day" | "evening" | "night";
  base: [string, string, string];
  glow1: RGB;
  glow1Alpha: number;
  glow2: RGB;
  glow2Alpha: number;
  night: number; // 0 vivid -> 1 calm/desaturated
}

// The canonical READY palette progression from TodayAtmosphereBackground.swift.
export const atmosphere: AtmospherePhase[] = [
  {
    key: "morning",
    base: ["#080f1a", "#05070d", "#030305"],
    glow1: [107, 184, 224],
    glow1Alpha: 0.16,
    glow2: [140, 209, 156],
    glow2Alpha: 0.1,
    night: 0.05,
  },
  {
    key: "day",
    base: ["#06090d", "#05070b", "#000000"],
    glow1: [140, 209, 156],
    glow1Alpha: 0.14,
    glow2: [128, 158, 235],
    glow2Alpha: 0.08,
    night: 0,
  },
  {
    key: "evening",
    base: ["#0a080f", "#050508", "#000000"],
    glow1: [173, 143, 230],
    glow1Alpha: 0.13,
    glow2: [237, 148, 66],
    glow2Alpha: 0.09,
    night: 0.55,
  },
  {
    key: "night",
    base: ["#04050a", "#020305", "#000000"],
    glow1: [128, 158, 235],
    glow1Alpha: 0.1,
    glow2: [140, 102, 217],
    glow2Alpha: 0.07,
    night: 1,
  },
];

function hexToRgb(hex: string): RGB {
  const h = hex.replace("#", "");
  const n = parseInt(
    h.length === 3
      ? h
          .split("")
          .map((c) => c + c)
          .join("")
      : h,
    16
  );
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function rgbToHex([r, g, b]: RGB): string {
  const c = (v: number) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0");
  return `#${c(r)}${c(g)}${c(b)}`;
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function lerpRgb(a: RGB, b: RGB, t: number): RGB {
  return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
}

export function lerpHex(a: string, b: string, t: number): string {
  return rgbToHex(lerpRgb(hexToRgb(a), hexToRgb(b), t));
}

// Given a global progress 0..1 across the whole day journey, return the
// interpolated atmosphere for the current scroll position.
export function atmosphereAt(progress: number): {
  base: [string, string, string];
  glow1: RGB;
  glow1Alpha: number;
  glow2: RGB;
  glow2Alpha: number;
  night: number;
} {
  const p = Math.max(0, Math.min(1, progress));
  const segs = atmosphere.length - 1;
  const scaled = p * segs;
  const i = Math.min(segs - 1, Math.floor(scaled));
  const t = scaled - i;
  const a = atmosphere[i];
  const b = atmosphere[i + 1];
  return {
    base: [
      lerpHex(a.base[0], b.base[0], t),
      lerpHex(a.base[1], b.base[1], t),
      lerpHex(a.base[2], b.base[2], t),
    ],
    glow1: lerpRgb(a.glow1, b.glow1, t),
    glow1Alpha: lerp(a.glow1Alpha, b.glow1Alpha, t),
    glow2: lerpRgb(a.glow2, b.glow2, t),
    glow2Alpha: lerp(a.glow2Alpha, b.glow2Alpha, t),
    night: lerp(a.night, b.night, t),
  };
}
