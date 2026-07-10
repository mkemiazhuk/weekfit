"use client";

import { motion, useReducedMotion } from "framer-motion";
import { pillars } from "@/lib/tokens";
import { easeCalm, stagger, durationReveal, durationCard } from "@/lib/motion";
import { useI18n } from "@/lib/i18n";
import TextReveal from "../TextReveal";
import SectionAmbient from "../SectionAmbient";
import Reveal from "../Reveal";

function FlowArrow() {
  return (
    <div className="flex justify-center py-1" aria-hidden>
      <div className="flex flex-col items-center gap-1 opacity-45">
        <div className="h-5 w-px bg-gradient-to-b from-white/0 via-white/22 to-white/0" />
        <svg viewBox="0 0 12 8" className="h-2 w-3 text-white/35" fill="currentColor">
          <path d="M6 8 0 0h12L6 8z" />
        </svg>
      </div>
    </div>
  );
}

export default function CoachReasoning() {
  const { t } = useI18n();
  const r = t.reasoning;
  const reduce = useReducedMotion();

  const step = (i: number) =>
    reduce
      ? {}
      : {
          initial: { opacity: 0, y: 14 },
          whileInView: { opacity: 1, y: 0 },
          viewport: { once: true, margin: "-8% 0px" },
          transition: { duration: durationReveal, ease: easeCalm, delay: i * stagger },
        };

  return (
    <section id="reasoning" className="relative z-[1] section-x section-y-lg">
      <SectionAmbient tone="coach" />
      <div className="mx-auto max-w-3xl">
        <Reveal>
          <span className="kicker text-coach">{r.kicker}</span>
          <TextReveal as="h2" delay={0.06} className="display section-title text-balance mt-4 text-white">
            {r.title}
          </TextReveal>
        </Reveal>

        <div className="mt-11 space-y-0 md:mt-12">
          <motion.div {...step(0)} className="card glass card-glass">
            <p className="kicker-sm">{r.yesterday}</p>
            <ul className="mt-4 space-y-2.5">
              {r.signals.map((s, i) => (
                <motion.li
                  key={s}
                  className="flex items-center gap-3 text-[15px] text-white/68"
                  {...(reduce
                    ? {}
                    : {
                        initial: { opacity: 0, x: -6 },
                        whileInView: { opacity: 1, x: 0 },
                        viewport: { once: true },
                        transition: { delay: 0.12 + i * 0.05, duration: durationCard, ease: easeCalm },
                      })}
                >
                  <span
                    className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[10px] font-bold"
                    style={{
                      color: pillars.activity,
                      background: `${pillars.activity}18`,
                      border: `1px solid ${pillars.activity}30`,
                    }}
                  >
                    ✓
                  </span>
                  {s}
                </motion.li>
              ))}
            </ul>
          </motion.div>

          <FlowArrow />

          <motion.div {...step(1)} className="flex justify-center py-2">
            <span className="inline-flex items-center gap-2 rounded-full border border-coach/20 bg-coach/8 px-4 py-2 text-[13px] font-medium text-white/58">
              <span className="h-1.5 w-1.5 rounded-full bg-coach/80" aria-hidden />
              {r.analyzing}
            </span>
          </motion.div>

          <FlowArrow />

          <motion.div {...step(2)} className="card glass card-glass">
            <p className="kicker-sm">{r.priority}</p>
            <p className="display mt-2 text-[clamp(1.85rem,5.5vw,2.65rem)] text-recovery">
              {r.priorityValue}
            </p>
          </motion.div>

          <FlowArrow />

          <motion.div {...step(3)} className="space-y-4">
            <div className="card glass card-glass">
              <p className="kicker-sm">{r.reasonLabel}</p>
              <p className="body-md mt-3 text-white/54">{r.reason}</p>
            </div>
            <div
              className="card glass card-glass card-accent"
              style={{ "--accent-color": pillars.coach } as React.CSSProperties}
            >
              <p className="kicker-sm">{r.recommendationLabel}</p>
              <p className="mt-4 flex flex-wrap items-baseline gap-x-3 gap-y-1 text-[clamp(1.2rem,3.8vw,1.55rem)] font-semibold leading-[1.35] tracking-[-0.02em]">
                <span className="text-white">{r.recommendationToday}</span>
                <span className="text-white/68">{r.recommendationTomorrow}</span>
              </p>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
