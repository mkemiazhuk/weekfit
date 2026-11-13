// WeekFit design tokens for JS-side use (rings, gradients, atmosphere).
// Extracted from the iOS app's Theme layer.

// Canonical app palette — WeekFitSemanticMetricTokens + WeekFitLightTokens.
export const pillars = {
  activity: "#72AD8A",
  nutrition: "#EAA06B",
  recovery: "#9B8ACB",
  hydration: "#35ADD0",
  coach: "#9B8ACB",
} as const;

export const pastels = {
  meal: "#72AD8A",
  workout: "#72AD8A",
  recovery: "#9B8ACB",
  habit: "#EAA06B",
} as const;

export const accents = {
  gold: "#B98A32",
  brand: "#72AD8A",
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

// Warm milk canvas from the app. Glows are sage, peach, and lavender — the page stays light.
export const atmosphere: AtmospherePhase[] = [
  {
    key: "morning",
    base: ["#FFF9EC", "#F7F6F2", "#F3F1EA"],
    glow1: [234, 160, 107],
    glow1Alpha: 0.28,
    glow2: [114, 173, 138],
    glow2Alpha: 0.2,
    night: 0,
  },
  {
    key: "day",
    base: ["#F7F6F2", "#F4F2EC", "#F0EEE9"],
    glow1: [114, 173, 138],
    glow1Alpha: 0.22,
    glow2: [155, 138, 203],
    glow2Alpha: 0.16,
    night: 0,
  },
  {
    key: "evening",
    base: ["#F8F3EA", "#F6F1E8", "#F3EEE6"],
    glow1: [155, 138, 203],
    glow1Alpha: 0.2,
    glow2: [234, 160, 107],
    glow2Alpha: 0.22,
    night: 0,
  },
  {
    key: "night",
    base: ["#F4F2F6", "#F3F1EA", "#EEEAE4"],
    glow1: [155, 138, 203],
    glow1Alpha: 0.18,
    glow2: [114, 173, 138],
    glow2Alpha: 0.12,
    night: 0,
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
