"use client";

import { useEffect, useRef, useState } from "react";
import Image from "next/image";
import clsx from "clsx";
import { motion, useReducedMotion } from "framer-motion";
import { pillars } from "@/lib/tokens";
import { easeCalm } from "@/lib/motion";
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
      accent: pillars.recovery,
      ambient: "recovery",
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

  function PhoneFrame({
    panel,
    className,
    sizes,
  }: {
    panel: Panel;
    className?: string;
    sizes: string;
  }) {
    return (
      <div className={clsx("relative w-full", className)}>
        <div
          aria-hidden
          className="phone-glow transition-all duration-700 opacity-50"
          style={{
            background: `radial-gradient(closest-side, ${panel.accent}28, transparent 70%)`,
            filter: "blur(32px)",
          }}
        />
        <div className="phone-frame transition-shadow duration-500">
          <div aria-hidden className="phone-island" />
          <div className="phone-screen">
            <Image src={panel.screen} alt={panel.screenAlt} fill sizes={sizes} className="object-cover" />
            <div
              aria-hidden
              className="pointer-events-none absolute inset-0 mix-blend-screen"
              style={{
                background:
                  "linear-gradient(135deg, rgba(255,255,255,0.16) 0%, rgba(255,255,255,0.03) 22%, transparent 46%)",
              }}
            />
          </div>
        </div>
      </div>
    );
  }

  return (
    <section id="experience" className="relative z-[1] section-x section-y-inset-top">
      <SectionAmbient tone={current.ambient} />
      <div className="mx-auto max-w-6xl md:grid md:grid-cols-2 md:gap-14">
        {/* Sticky morphing phone (desktop) */}
        <div className="hidden md:block">
          <div className="sticky top-0 flex h-screen items-center justify-center">
            <div className="relative w-full max-w-[320px]">
              <div
                className="phone-frame phone-frame--hero transition-shadow duration-700"
                style={{
                  boxShadow: `0 48px 100px -28px rgba(0,0,0,0.72), 0 0 48px -24px ${current.accent}22`,
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
                      sizes="320px"
                      className={clsx(
                        "object-cover transition-opacity duration-700",
                        i === active ? "opacity-100" : "opacity-0"
                      )}
                    />
                  ))}
                </div>
              </div>

              <div
                key={current.key}
                className="absolute -bottom-4 -right-6 w-[min(100%,240px)] max-w-[240px]"
                style={{ animation: reduce ? "none" : "coach-swap 0.6s var(--ease-calm)" }}
              >
                <JourneySignalCard
                  accent={current.accent}
                  signal={current.coach.signal}
                  tip={current.coach.tip}
                  detail={current.coach.detail}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Scrolling panels */}
        <div>
          {panels.map((p, i) => (
            <div
              key={p.key}
              ref={(el) => {
                panelRefs.current[i] = el;
              }}
              data-idx={i}
              className={clsx(
                "relative flex min-h-[64vh] flex-col justify-center py-12 md:min-h-[84vh] md:py-[4rem]",
                p.layout === "statement" && "md:min-h-[64vh]"
              )}
            >
              <div className="relative mb-6 flex justify-center pb-8 md:hidden md:pb-0">
                <PhoneFrame panel={p} className="max-w-[240px]" sizes="240px" />
                <div className="absolute -bottom-2 left-1/2 w-[min(88vw,240px)] max-w-[240px] -translate-x-1/2">
                  <JourneySignalCard
                    accent={p.accent}
                    signal={p.coach.signal}
                    tip={p.coach.tip}
                    detail={p.coach.detail}
                    floating
                  />
                </div>
              </div>

              <motion.div
                initial={reduce ? {} : { opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-20% 0px" }}
                transition={{ duration: 0.7, ease: easeCalm }}
                className="text-center md:text-left"
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
                <p className="body-md section-lead mx-auto mt-4 md:mx-0">{p.body}</p>
              </motion.div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
