"use client";

import { motion, useReducedMotion } from "framer-motion";
import { pillars } from "@/lib/tokens";
import { easeCalm, stagger } from "@/lib/motion";
import { useI18n } from "@/lib/i18n";
import SectionAmbient from "../SectionAmbient";
import Reveal from "../Reveal";

function FlowArrow({ reduce }: { reduce: boolean | null }) {
  return (
    <div className="flex justify-center py-1" aria-hidden>
      {reduce ? (
        <div className="flex flex-col items-center gap-1 opacity-50">
          <div className="h-5 w-px bg-white/20" />
          <svg viewBox="0 0 12 8" className="h-2 w-3 text-white/40" fill="currentColor">
            <path d="M6 8 0 0h12L6 8z" />
          </svg>
        </div>
      ) : (
        <motion.div
          className="flex flex-col items-center gap-1"
          animate={{ opacity: [0.3, 0.7, 0.3] }}
          transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
        >
          <div className="h-5 w-px bg-gradient-to-b from-white/0 via-white/30 to-white/0" />
          <svg viewBox="0 0 12 8" className="h-2 w-3 text-white/40" fill="currentColor">
            <path d="M6 8 0 0h12L6 8z" />
          </svg>
        </motion.div>
      )}
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
          initial: { opacity: 0, y: 16 },
          whileInView: { opacity: 1, y: 0 },
          viewport: { once: true, margin: "-8% 0px" },
          transition: { duration: 0.75, ease: easeCalm, delay: i * stagger },
        };

  return (
    <section id="reasoning" className="relative px-5 py-20 md:px-6 md:py-28">
      <SectionAmbient tone="coach" />
      <div className="mx-auto max-w-2xl">
        <Reveal>
          <span className="text-[13px] font-bold uppercase tracking-[0.18em] text-coach">
            {r.kicker}
          </span>
          <h2 className="display mt-3 text-[clamp(2rem,5vw,3.2rem)] text-white">
            {r.title}
          </h2>
        </Reveal>

        <div className="mt-12 space-y-0">
          {/* Yesterday signals */}
          <motion.div {...step(0)} className="glass rounded-[22px] p-5 md:p-6">
            <p className="text-[11px] font-bold uppercase tracking-[0.16em] text-white/40">
              {r.yesterday}
            </p>
            <ul className="mt-4 space-y-2.5">
              {r.signals.map((s, i) => (
                <motion.li
                  key={s}
                  className="flex items-center gap-3 text-[15px] text-white/80"
                  {...(reduce
                    ? {}
                    : {
                        initial: { opacity: 0, x: -8 },
                        whileInView: { opacity: 1, x: 0 },
                        viewport: { once: true },
                        transition: { delay: 0.15 + i * 0.06, duration: 0.5, ease: easeCalm },
                      })}
                >
                  <span
                    className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[10px] font-bold"
                    style={{
                      color: pillars.activity,
                      background: `${pillars.activity}22`,
                      border: `1px solid ${pillars.activity}44`,
                    }}
                  >
                    ✓
                  </span>
                  {s}
                </motion.li>
              ))}
            </ul>
          </motion.div>

          <FlowArrow reduce={reduce} />

          {/* Analyzing */}
          <motion.div {...step(1)} className="flex justify-center py-2">
            <span className="inline-flex items-center gap-2.5 rounded-full border border-coach/25 bg-coach/10 px-4 py-2 text-[13px] font-medium text-white/75">
              {!reduce && (
                <motion.span
                  className="h-1.5 w-1.5 rounded-full bg-coach"
                  animate={{ opacity: [0.4, 1, 0.4], scale: [0.9, 1.1, 0.9] }}
                  transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
                  style={{ boxShadow: `0 0 10px ${pillars.coach}` }}
                />
              )}
              {r.analyzing}
            </span>
          </motion.div>

          <FlowArrow reduce={reduce} />

          {/* Priority */}
          <motion.div {...step(2)} className="glass rounded-[22px] p-5 md:p-6">
            <p className="text-[11px] font-bold uppercase tracking-[0.16em] text-white/40">
              {r.priority}
            </p>
            <p
              className="display mt-2 text-[clamp(2rem,6vw,2.8rem)]"
              style={{ color: pillars.recovery }}
            >
              {r.priorityValue}
            </p>
          </motion.div>

          <FlowArrow reduce={reduce} />

          {/* Reason + Recommendation */}
          <motion.div {...step(3)} className="space-y-4">
            <div className="glass rounded-[22px] p-5 md:p-6">
              <p className="text-[11px] font-bold uppercase tracking-[0.16em] text-white/40">
                {r.reasonLabel}
              </p>
              <p className="mt-3 text-[15px] leading-relaxed text-white/70 md:text-[16px]">
                {r.reason}
              </p>
            </div>
            <div
              className="rounded-[22px] p-5 md:p-6"
              style={{
                background: `linear-gradient(150deg, ${pillars.coach}20, rgba(255,255,255,0.04))`,
                border: `1px solid ${pillars.coach}35`,
                boxShadow: `0 20px 50px -20px ${pillars.coach}40`,
              }}
            >
              <p className="text-[11px] font-bold uppercase tracking-[0.16em] text-white/40">
                {r.recommendationLabel}
              </p>
              <p className="display mt-3 text-[clamp(1.4rem,4vw,1.85rem)] text-white">
                {r.recommendation}
              </p>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
