"use client";

import { useEffect, useRef, useState } from "react";
import Image from "next/image";
import clsx from "clsx";
import { motion, AnimatePresence, useReducedMotion } from "framer-motion";
import { pillars } from "@/lib/tokens";
import { easeCalm, durationCard } from "@/lib/motion";
import { useI18n } from "@/lib/i18n";
import JourneySignalCard from "../JourneySignalCard";
import SectionAmbient from "../SectionAmbient";

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
      screenAlt: "WeekFit recovery screen with stretching and sleep guidance",
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
      screenAlt: "WeekFit Coach screen with wind-down guidance for the evening",
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

  function StickyPhone({ className, sizes }: { className?: string; sizes: string }) {
    return (
      <div className={clsx("journey-stage-phone", className)}>
        <div
          aria-hidden
          className="phone-glow phone-glow--hero transition-all duration-700"
          style={{
            background: `radial-gradient(closest-side, ${current.accent}28, transparent 72%)`,
          }}
        />
        <div
          className="phone-frame phone-frame--hero transition-shadow duration-700"
          style={{
            boxShadow: `0 56px 120px -32px rgba(0,0,0,0.78), 0 0 40px -24px ${current.accent}24`,
          }}
        >
          <div aria-hidden className="phone-island" />
          <div className="phone-screen">
            {panels.map((p, i) => (
              <Image
                key={p.key}
                src={p.screen}
                alt={i === active ? p.screenAlt : ""}
                fill
                sizes={sizes}
                className={clsx(
                  "object-cover transition-opacity duration-700 ease-[cubic-bezier(0.22,1,0.36,1)]",
                  i === active ? "opacity-100" : "opacity-0"
                )}
              />
            ))}
            <div
              aria-hidden
              className="pointer-events-none absolute inset-0 mix-blend-screen"
              style={{
                background:
                  "linear-gradient(135deg, rgba(255,255,255,0.12) 0%, rgba(255,255,255,0.02) 24%, transparent 48%)",
              }}
            />
          </div>
        </div>

        <AnimatePresence mode="wait">
          <motion.div
            key={current.key}
            initial={reduce ? false : { opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduce ? undefined : { opacity: 0, y: -4 }}
            transition={{ duration: durationCard, ease: easeCalm }}
            className="journey-stage-signal mt-5 w-full"
          >
            <JourneySignalCard
              accent={current.accent}
              signal={current.coach.signal}
              tip={current.coach.tip}
              detail={current.coach.detail}
            />
          </motion.div>
        </AnimatePresence>
      </div>
    );
  }

  return (
    <section id="experience" className="relative z-[1] section-x section-y-inset-top">
      <SectionAmbient tone={current.ambient} />

      <div className="mx-auto max-w-6xl">
        <div className="journey-stage-phone-mobile sticky top-[4.75rem] z-10 mx-auto mb-10 max-w-[252px] md:hidden">
          <StickyPhone sizes="252px" />
        </div>

        <div className="md:grid md:grid-cols-2 md:gap-14 lg:gap-16">
          <div className="hidden md:block">
            <div className="sticky top-0 flex h-screen items-center justify-center">
              <StickyPhone className="max-w-[320px]" sizes="320px" />
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
                    "relative flex min-h-[68vh] flex-col justify-center py-12 md:min-h-[86vh] md:py-[4.5rem]",
                    p.layout === "statement" && "md:min-h-[72vh]"
                  )}
                >
                  <div
                    className={clsx(
                      "journey-stage-copy text-center transition-opacity duration-500 md:text-left",
                      isActive ? "opacity-100" : "opacity-40"
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
                    <p className="body-lg section-lead mx-auto mt-4 max-w-[var(--measure-prose)] md:mx-0">
                      {p.body}
                    </p>
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
