export interface SpotlightRegion {
  top: number;
  left: number;
  width: number;
  height: number;
  radius?: number;
}

/** Spotlight regions tuned per screenshot — highlights the UI that matches each panel's story. */
export const journeyPanelSpotlights: Record<string, SpotlightRegion> = {
  /** Today — overview rings (recovery, activity, nutrition) */
  morning: { top: 27, left: 3.5, width: 93, height: 27, radius: 18 },
  /** Meals — pre-workout guidance card */
  prep: { top: 34, left: 5, width: 90, height: 24, radius: 16 },
  /** Activity — training rings / session block */
  workout: { top: 25, left: 4.5, width: 91, height: 28, radius: 16 },
  /** Recovery details — prior-day training load row */
  recovery: { top: 70.5, left: 4.5, width: 91, height: 9, radius: 10 },
  /** Coach — today's recommendation card */
  night: { top: 25.5, left: 5, width: 90, height: 36, radius: 18 },
};

export function spotlightImagePosition(region: SpotlightRegion) {
  return {
    width: `${(100 / region.width) * 100}%`,
    height: `${(100 / region.height) * 100}%`,
    left: `${(-region.left / region.width) * 100}%`,
    top: `${(-region.top / region.height) * 100}%`,
  };
}
