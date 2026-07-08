"use client";

import { useEffect, useRef, useState } from "react";
import Image from "next/image";
import clsx from "clsx";
import { motion, useReducedMotion } from "framer-motion";
import { pillars } from "@/lib/tokens";
import { easeCalm } from "@/lib/motion";
import { useI18n } from "@/lib/i18n";
import CoachCard from "../CoachCard";
import SectionAmbient from "../SectionAmbient";

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
  state: string;
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
      state: "Ready",
      layout: "default",
    },
    {
      key: "prep",
      screen: "/img/coach.jpg",
      screenAlt: "WeekFit Coach screen with the day's personalized guidance",
      accent: pillars.coach,
      ambient: "coach",
      kicker: t.prep.kicker,
      title: t.prep.title,
      body: t.prep.body,
      state: "Prepare",
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
      state: "Training",
      layout: "default",
    },
    {
      key: "recovery",
      screen: "/img/nutrition.jpg",
      screenAlt: "WeekFit Nutrition screen with calories and macro balance",
      accent: pillars.nutrition,
      ambient: "nutrition",
      kicker: t.recovery.kicker,
      title: t.recovery.title,
      body: t.recovery.body,
      state: "Refuel",
      layout: "default",
    },
    {
      key: "night",
      screen: "/img/recovery.jpg",
      screenAlt: "WeekFit recovery and sleep wind-down screen for the evening",
      accent: pillars.recovery,
      ambient: "recovery",
      kicker: t.night.kicker,
      title: t.night.title,
      body: t.night.body,
      state: "Wind down",
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
          className="absolute -inset-[16%] -z-10 rounded-[50%] transition-all duration-700"
          style={{
            background: `radial-gradient(closest-side, ${panel.accent}3d, transparent 70%)`,
            filter: "blur(38px)",
          }}
        />
        <div
          className="relative w-full overflow-hidden rounded-[13.5%] p-[3%] transition-shadow duration-500"
          style={{
            aspectRatio: "900 / 1950",
            background: "linear-gradient(150deg, #202227, #0c0d11 60%, #060709)",
            border: "1px solid rgba(255,255,255,0.14)",
            boxShadow: "0 60px 130px -30px rgba(0,0,0,0.75), inset 0 0 0 1.5px rgba(255,255,255,0.04)",
          }}
        >
          <div className="absolute left-1/2 top-[2.4%] z-20 h-[2.4%] w-[30%] -translate-x-1/2 rounded-full bg-black" />
          <div className="relative h-full w-full overflow-hidden rounded-[11%]">
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
    <section id="experience" className="relative">
      <SectionAmbient tone={current.ambient} />
      <div className="mx-auto max-w-6xl px-6 md:grid md:grid-cols-2 md:gap-16">
        {/* Sticky morphing phone (desktop) */}
        <div className="hidden md:block">
          <div className="sticky top-0 flex h-screen items-center justify-center">
            <div className="relative w-full max-w-[300px]">
              <div
                className="relative w-full overflow-hidden rounded-[13.5%] p-[3%] transition-shadow duration-700"
                style={{
                  aspectRatio: "900 / 1950",
                  background: "linear-gradient(150deg, #202227, #0c0d11 60%, #060709)",
                  border: "1px solid rgba(255,255,255,0.14)",
                  boxShadow: `0 60px 130px -30px rgba(0,0,0,0.75), 0 0 60px -20px ${current.accent}33`,
                }}
              >
                <div className="absolute left-1/2 top-[2.4%] z-20 h-[2.4%] w-[30%] -translate-x-1/2 rounded-full bg-black" />
                <div className="relative h-full w-full overflow-hidden rounded-[11%]">
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
                className="absolute -bottom-4 -right-6 w-[240px]"
                style={{ animation: reduce ? "none" : "coach-swap 0.6s var(--ease-calm)" }}
              >
                <CoachCard
                  accent={current.accent}
                  state={current.state}
                  title={current.title}
                  body={current.body}
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
                "relative flex min-h-[78vh] flex-col justify-center py-14 md:min-h-screen md:py-16",
                p.layout === "statement" && "md:min-h-[70vh]"
              )}
            >
              <div className="mb-8 flex justify-center md:hidden">
                <PhoneFrame panel={p} className="max-w-[260px]" sizes="260px" />
              </div>

              <motion.div
                initial={reduce ? {} : { opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-20% 0px" }}
                transition={{ duration: 0.7, ease: easeCalm }}
              >
                <span
                  className="text-[13px] font-bold uppercase tracking-[0.18em]"
                  style={{ color: p.accent }}
                >
                  {p.kicker}
                </span>
                <h2
                  className={clsx(
                    "display mt-3 text-white",
                    p.layout === "statement"
                      ? "text-[clamp(2.4rem,5vw,3.6rem)]"
                      : "text-[clamp(2rem,4.5vw,3.1rem)]"
                  )}
                >
                  {p.title}
                </h2>
                <p className="mt-3 max-w-[38ch] text-[16px] leading-relaxed text-white/55 md:mt-4">
                  {p.body}
                </p>
              </motion.div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
