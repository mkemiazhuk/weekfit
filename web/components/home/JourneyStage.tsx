"use client";

import { useEffect, useRef, useState } from "react";
import clsx from "clsx";
import { motion, AnimatePresence, useReducedMotion } from "framer-motion";
import { pillars } from "@/lib/tokens";
import { easeCalm, durationCard } from "@/lib/motion";
import { useI18n } from "@/lib/i18n";
import SectionAmbient from "../SectionAmbient";
import JourneySpotlightPhone from "./JourneySpotlightPhone";

type AmbientTone = "morning" | "coach" | "activity" | "nutrition" | "recovery";

interface StageSignal {
  signal: string;
  tip: string;
  detail: string;
}

interface Panel {
  key: string;
  screen: string;
  screenAlt: string;
  accent: string;
  ambient: AmbientTone;
  kicker: string;
  title: string;
  body: string;
  coach: StageSignal;
  layout: "default" | "statement";
}

export default function JourneyStage() {
  const { t } = useI18n();
  const reduce = useReducedMotion();

  const panels: Panel[] = [
    {
      key: "morning",
      screen: "/img/today.jpg",
      screenAlt: "WeekFit Today screen showing recovery, activity and nutrition rings",
      accent: pillars.recovery,
      ambient: "morning",
      kicker: t.morning.kicker,
      title: t.morning.title,
      body: t.morning.body,
      coach: t.morning.coach,
      layout: "default",
    },
    {
      key: "prep",
      screen: "/img/meals.jpg",
      screenAlt: "WeekFit Meals screen with pre-workout nutrition guidance",
      accent: pillars.nutrition,
      ambient: "nutrition",
      kicker: t.prep.kicker,
      title: t.prep.title,
      body: t.prep.body,
      coach: t.prep.coach,
      layout: "statement",
    },
    {
      key: "workout",
      screen: "/img/activity.jpg",
      screenAlt: "WeekFit Activity screen with workouts synced from Apple Health",
      accent: pillars.activity,
      ambient: "activity",
      kicker: t.workout.kicker,
      title: t.workout.title,
      body: t.workout.body,
      coach: t.workout.coach,
      layout: "default",
    },
    {
      key: "recovery",
      screen: "/img/recovery.jpg",
      screenAlt: "WeekFit recovery screen with training load in the breakdown",
      accent: pillars.recovery,
      ambient: "recovery",
      kicker: t.recovery.kicker,
      title: t.recovery.title,
      body: t.recovery.body,
      coach: t.recovery.coach,
      layout: "default",
    },
    {
      key: "night",
      screen: "/img/coach.jpg",
      screenAlt: "WeekFit Coach screen with today's recommendation",
      accent: pillars.coach,
      ambient: "coach",
      kicker: t.night.kicker,
      title: t.night.title,
      body: t.night.body,
      coach: t.night.coach,
      layout: "statement",
    },
  ];

  const [active, setActive] = useState(0);
  const panelRefs = useRef<(HTMLDivElement | null)[]>([]);
  const ratios = useRef<number[]>(panels.map(() => 0));

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          const idx = Number((e.target as HTMLElement).dataset.idx);
          ratios.current[idx] = e.isIntersecting ? e.intersectionRatio : 0;
        }
        let best = 0;
        let bestRatio = -1;
        ratios.current.forEach((r, i) => {
          if (r > bestRatio) {
            bestRatio = r;
            best = i;
          }
        });
        setActive(best);
      },
      { rootMargin: "-40% 0px -40% 0px", threshold: [0, 0.25, 0.5, 0.75, 1] }
    );
    panelRefs.current.forEach((el) => el && observer.observe(el));
    return () => observer.disconnect();
  }, []);

  const current = panels[active];

  return (
    <section id="experience" className="relative z-[1] section-x section-y-inset-top">
      <SectionAmbient tone={current.ambient} />

      <div className="mx-auto max-w-6xl">
        <div className="journey-stage-phone-mobile sticky top-[4.75rem] z-[1] mx-auto mb-10 max-w-[252px] md:hidden">
          <JourneySpotlightPhone panels={panels} activeIndex={active} sizes="252px" />
        </div>

        <div className="journey-stage-scroll md:grid md:grid-cols-2 md:gap-14 lg:gap-16">
          <div className="hidden md:block">
            <div className="sticky top-0 flex h-screen items-center justify-center">
              <JourneySpotlightPhone
                panels={panels}
                activeIndex={active}
                className="max-w-[320px]"
                sizes="320px"
              />
            </div>
          </div>

          <div>
            {panels.map((p, i) => {
              const isActive = i === active;

              return (
                <div
                  key={p.key}
                  ref={(el) => {
                    panelRefs.current[i] = el;
                  }}
                  data-idx={i}
                  className={clsx(
                    "journey-stage-panel relative flex min-h-[68vh] flex-col justify-center py-12 md:min-h-[86vh] md:py-[4.5rem]",
                    p.layout === "statement" && "md:min-h-[72vh]"
                  )}
                >
                  <div
                    className={clsx(
                      "journey-stage-copy text-center transition-opacity duration-500 md:text-left",
                      isActive ? "opacity-100" : "opacity-36"
                    )}
                  >
                    <span className="kicker" style={{ color: p.accent }}>
                      {p.kicker}
                    </span>
                    <h2
                      className={clsx(
                        "display section-title text-balance mt-4 text-white",
                        p.layout === "statement" && "section-title-lg"
                      )}
                    >
                      {p.title}
                    </h2>

                    <AnimatePresence mode="wait">
                      {isActive && (
                        <motion.div
                          key={p.key}
                          initial={reduce ? false : { opacity: 0, y: 10 }}
                          animate={{ opacity: 1, y: 0 }}
                          exit={reduce ? undefined : { opacity: 0, y: -6 }}
                          transition={{ duration: durationCard, ease: easeCalm }}
                          className="mt-5 max-w-[var(--measure-prose)] mx-auto md:mx-0"
                        >
                          <p
                            className="text-[1.0625rem] font-semibold leading-snug tracking-[-0.018em] md:text-[1.125rem]"
                            style={{ color: p.accent }}
                          >
                            {p.coach.signal}
                          </p>
                          <p className="body-lg mt-3">{p.coach.tip}</p>
                          <p className="body-md mt-2.5">{p.coach.detail}</p>
                        </motion.div>
                      )}
                    </AnimatePresence>

                    {!isActive && (
                      <p className="body-md mt-4 max-w-[var(--measure-prose)] mx-auto md:mx-0">
                        {p.body}
                      </p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
