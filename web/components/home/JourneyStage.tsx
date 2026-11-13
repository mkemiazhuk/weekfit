"use client";

import { useState } from "react";
import clsx from "clsx";
import { pillars } from "@/lib/tokens";
import { useI18n } from "@/lib/i18n";
import { screenImagePath } from "@/lib/screen-images";
import SectionAmbient from "../SectionAmbient";
import JourneySpotlightPhone from "./JourneySpotlightPhone";

type AmbientTone = "morning" | "coach" | "activity" | "nutrition" | "recovery";

interface Panel {
  key: string;
  screen: string;
  screenAlt: string;
  accent: string;
  ambient: AmbientTone;
  kicker: string;
  title: string;
  body: string;
}

export default function JourneyStage() {
  const { t } = useI18n();
  const [active, setActive] = useState(0);

  const panels: Panel[] = [
    {
      key: "morning",
      screen: screenImagePath("today"),
      screenAlt: "WeekFit Today screen showing recovery, activity and nutrition rings",
      accent: pillars.recovery,
      ambient: "morning",
      kicker: t.morning.kicker,
      title: t.morning.title,
      body: t.morning.body,
    },
    {
      key: "prep",
      screen: screenImagePath("meals"),
      screenAlt: "WeekFit Meals screen with pre-workout nutrition guidance",
      accent: pillars.nutrition,
      ambient: "nutrition",
      kicker: t.prep.kicker,
      title: t.prep.title,
      body: t.prep.body,
    },
    {
      key: "workout",
      screen: screenImagePath("activity"),
      screenAlt: "WeekFit Activity screen with workouts synced from Apple Health",
      accent: pillars.activity,
      ambient: "activity",
      kicker: t.workout.kicker,
      title: t.workout.title,
      body: t.workout.body,
    },
    {
      key: "recovery",
      screen: screenImagePath("recovery"),
      screenAlt: "WeekFit recovery screen with training load in the breakdown",
      accent: pillars.recovery,
      ambient: "recovery",
      kicker: t.recovery.kicker,
      title: t.recovery.title,
      body: t.recovery.body,
    },
    {
      key: "night",
      screen: screenImagePath("coach"),
      screenAlt: "WeekFit Coach screen with today's recommendation",
      accent: pillars.coach,
      ambient: "coach",
      kicker: t.night.kicker,
      title: t.night.title,
      body: t.night.body,
    },
  ];

  const current = panels[active];

  return (
    <section id="experience" className="relative z-[1] section-x py-8 md:py-12">
      <SectionAmbient tone={current.ambient} />

      <div className="mx-auto grid max-w-6xl items-center gap-8 md:grid-cols-[minmax(0,300px)_minmax(0,1fr)] md:gap-10 lg:grid-cols-[minmax(0,320px)_minmax(0,1fr)] lg:gap-14">
        <div className="mx-auto w-full max-w-[240px] md:max-w-none">
          <JourneySpotlightPhone panels={panels} activeIndex={active} sizes="320px" />
        </div>

        <div className="flex flex-col">
          {panels.map((p, i) => {
            const on = i === active;
            return (
              <div
                key={p.key}
                role="button"
                tabIndex={0}
                aria-pressed={on}
                onClick={() => setActive(i)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    setActive(i);
                  }
                }}
                className={clsx(
                  "cursor-pointer border-l-2 py-3 pl-5 text-left md:py-3.5 md:pl-6",
                  on ? "" : "border-black/10"
                )}
                style={on ? { borderColor: p.accent } : undefined}
              >
                <span className="kicker" style={{ color: p.accent }}>
                  {p.kicker}
                </span>
                <h2 className="mt-1 text-[1.65rem] font-semibold leading-[1.08] tracking-[-0.03em] text-[#292b28] md:text-[2.05rem]">
                  {p.title}
                </h2>
                <p className="mt-1.5 max-w-[38rem] text-[1.0625rem] leading-snug text-[#3a3d3a] md:text-[1.1875rem]">
                  {p.body}
                </p>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
