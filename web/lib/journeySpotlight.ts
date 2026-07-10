import { pillars } from "./tokens";

export interface SpotlightRegion {
  top: number;
  left: number;
  width: number;
  height: number;
  radius?: number;
}

export interface JourneySpotlightStep {
  id: string;
  screen: string;
  screenAlt: string;
  accent: string;
  ambient: "morning" | "recovery" | "activity" | "nutrition" | "coach";
  region: SpotlightRegion;
  contentKey: keyof JourneyStepContentMap;
}

export interface JourneyStepCopy {
  label: string;
  signal: string;
  tip: string;
  detail: string;
}

export type JourneyStepContentMap = {
  recoveryScore: JourneyStepCopy;
  hrv: JourneyStepCopy;
  sleep: JourneyStepCopy;
  trainingLoad: JourneyStepCopy;
  coachRec: JourneyStepCopy;
};

/** Percent-based regions tuned to /img/recovery.jpg and /img/coach.jpg screenshots. */
export const journeySpotlightSteps: JourneySpotlightStep[] = [
  {
    id: "recovery-score",
    screen: "/img/recovery.jpg",
    screenAlt: "WeekFit recovery score on the Recovery details screen",
    accent: pillars.recovery,
    ambient: "recovery",
    region: { top: 18.5, left: 4.5, width: 91, height: 22.5, radius: 16 },
    contentKey: "recoveryScore",
  },
  {
    id: "hrv",
    screen: "/img/recovery.jpg",
    screenAlt: "HRV reading on the Recovery details screen",
    accent: pillars.recovery,
    ambient: "recovery",
    region: { top: 40.5, left: 35, width: 30, height: 9.5, radius: 12 },
    contentKey: "hrv",
  },
  {
    id: "sleep",
    screen: "/img/recovery.jpg",
    screenAlt: "Sleep metrics on the Recovery details screen",
    accent: pillars.recovery,
    ambient: "recovery",
    region: { top: 40.5, left: 5, width: 28, height: 9.5, radius: 12 },
    contentKey: "sleep",
  },
  {
    id: "training-load",
    screen: "/img/recovery.jpg",
    screenAlt: "Prior-day training load in the recovery breakdown",
    accent: pillars.activity,
    ambient: "activity",
    region: { top: 71.5, left: 4.5, width: 91, height: 8, radius: 10 },
    contentKey: "trainingLoad",
  },
  {
    id: "coach-rec",
    screen: "/img/coach.jpg",
    screenAlt: "WeekFit Coach recommendation for today",
    accent: pillars.coach,
    ambient: "coach",
    region: { top: 26, left: 5.5, width: 89, height: 34, radius: 18 },
    contentKey: "coachRec",
  },
];
