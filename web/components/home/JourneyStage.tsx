"use client";

import { useEffect, useRef, useState } from "react";
import Image from "next/image";
import clsx from "clsx";
import { pillars } from "@/lib/tokens";
import { useI18n } from "@/lib/i18n";
import CoachCard from "../CoachCard";

interface Panel {
  key: string;
  screen: string;
  accent: string;
  kicker: string;
  title: string;
  body: string;
  state: string;
}

export default function JourneyStage() {
  const { t } = useI18n();

  const panels: Panel[] = [
    {
      key: "morning",
      screen: "/img/today.jpg",
      accent: pillars.recovery,
      kicker: t.morning.kicker,
      title: t.morning.title,
      body: t.morning.body,
      state: "Ready",
    },
    {
      key: "prep",
      screen: "/img/coach.jpg",
      accent: pillars.coach,
      kicker: t.prep.kicker,
      title: t.prep.title,
      body: t.prep.body,
      state: "Prepare",
    },
    {
      key: "workout",
      screen: "/img/activity.jpg",
      accent: pillars.activity,
      kicker: t.workout.kicker,
      title: t.workout.title,
      body: t.workout.body,
      state: "Training",
    },
    {
      key: "recovery",
      screen: "/img/nutrition.jpg",
      accent: pillars.nutrition,
      kicker: t.recovery.kicker,
      title: t.recovery.title,
      body: t.recovery.body,
      state: "Refuel",
    },
    {
      key: "night",
      screen: "/img/recovery.jpg",
      accent: pillars.recovery,
      kicker: t.night.kicker,
      title: t.night.title,
      body: t.night.body,
      state: "Wind down",
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
    <section id="experience" className="relative">
      <div className="mx-auto max-w-6xl px-6 md:grid md:grid-cols-2 md:gap-16">
        {/* Sticky morphing phone (desktop) */}
        <div className="hidden md:block">
          <div className="sticky top-0 flex h-screen items-center justify-center">
            <div className="relative w-full max-w-[300px]">
              {/* accent glow */}
              <div
                aria-hidden
                className="absolute -inset-[16%] -z-10 rounded-[50%] transition-all duration-700"
                style={{
                  background: `radial-gradient(closest-side, ${current.accent}3d, transparent 70%)`,
                  filter: "blur(38px)",
                }}
              />
              {/* device frame (static) with crossfading screens */}
              <div
                className="relative w-full overflow-hidden rounded-[13.5%] p-[3%]"
                style={{
                  aspectRatio: "900 / 1950",
                  background:
                    "linear-gradient(150deg, #202227, #0c0d11 60%, #060709)",
                  border: "1px solid rgba(255,255,255,0.14)",
                  boxShadow:
                    "0 60px 130px -30px rgba(0,0,0,0.75), inset 0 0 0 1.5px rgba(255,255,255,0.04)",
                }}
              >
                <div className="absolute left-1/2 top-[2.4%] z-20 h-[2.4%] w-[30%] -translate-x-1/2 rounded-full bg-black" />
                <div className="relative h-full w-full overflow-hidden rounded-[11%]">
                  {panels.map((p, i) => (
                    <Image
                      key={p.key}
                      src={p.screen}
                      alt={`WeekFit ${p.key}`}
                      fill
                      sizes="320px"
                      className={clsx(
                        "object-cover transition-opacity duration-700",
                        i === active ? "opacity-100" : "opacity-0"
                      )}
                    />
                  ))}
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

              {/* floating coach card reflects active state */}
              <div
                key={current.key}
                className="absolute -bottom-4 -right-6 w-[240px]"
                style={{ animation: "coach-swap 0.6s var(--ease-calm)" }}
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
              className="flex min-h-[86vh] flex-col justify-center py-16 md:min-h-screen"
            >
              {/* Mobile phone */}
              <div className="mb-10 flex justify-center md:hidden">
                <div className="relative w-full max-w-[260px]">
                  <div
                    aria-hidden
                    className="absolute -inset-[16%] -z-10 rounded-[50%]"
                    style={{
                      background: `radial-gradient(closest-side, ${p.accent}3d, transparent 70%)`,
                      filter: "blur(30px)",
                    }}
                  />
                  <div
                    className="relative w-full overflow-hidden rounded-[13.5%] p-[3%]"
                    style={{
                      aspectRatio: "900 / 1950",
                      background:
                        "linear-gradient(150deg, #202227, #0c0d11 60%, #060709)",
                      border: "1px solid rgba(255,255,255,0.14)",
                      boxShadow: "0 40px 90px -30px rgba(0,0,0,0.75)",
                    }}
                  >
                    <div className="absolute left-1/2 top-[2.4%] z-20 h-[2.4%] w-[30%] -translate-x-1/2 rounded-full bg-black" />
                    <div className="relative h-full w-full overflow-hidden rounded-[11%]">
                      <Image
                        src={p.screen}
                        alt={`WeekFit ${p.key}`}
                        fill
                        sizes="260px"
                        className="object-cover"
                      />
                    </div>
                  </div>
                </div>
              </div>

              <span
                className="text-[13px] font-bold uppercase tracking-[0.18em]"
                style={{ color: p.accent }}
              >
                {p.kicker}
              </span>
              <h2 className="display mt-3 text-[clamp(2rem,4.5vw,3.1rem)] text-white">
                {p.title}
              </h2>
              <p className="mt-4 max-w-[42ch] text-[clamp(1.02rem,2vw,1.18rem)] leading-relaxed text-white/60">
                {p.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
