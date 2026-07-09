"use client";

import { motion, useReducedMotion } from "framer-motion";
import { useI18n } from "@/lib/i18n";
import { pillars } from "@/lib/tokens";
import { easeCalm } from "@/lib/motion";
import ProgressRing from "../ProgressRing";

const ringColors = {
  recovery: pillars.recovery,
  activity: pillars.activity,
  nutrition: pillars.nutrition,
} as const;

type RingColorKey = keyof typeof ringColors;

export default function DownloadHeroPhone() {
  const { t } = useI18n();
  const reduce = useReducedMotion();
  const p = t.cta.heroPhone;

  const stagger = (i: number) =>
    reduce
      ? {}
      : {
          initial: { opacity: 0, y: 10 },
          animate: { opacity: 1, y: 0 },
          transition: { duration: 0.7, ease: easeCalm, delay: 0.85 + i * 0.08 },
        };

  return (
    <div className="download-hero-phone">
      <motion.div
        aria-hidden
        className="download-hero-phone__glow download-hero-phone__glow--recovery"
        animate={reduce ? {} : { opacity: [0.5, 0.85, 0.5], scale: [1, 1.08, 1] }}
        transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
      />
      <motion.div
        aria-hidden
        className="download-hero-phone__glow download-hero-phone__glow--coach"
        animate={reduce ? {} : { opacity: [0.35, 0.6, 0.35], scale: [1.04, 1, 1.04] }}
        transition={{ duration: 10, repeat: Infinity, ease: "easeInOut", delay: 1.2 }}
      />

      <div className="phone-frame download-hero-phone__frame">
        <div aria-hidden className="phone-island" />
        <div className="phone-screen download-hero-phone__screen">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0"
            style={{
              background:
                "radial-gradient(120% 80% at 50% -10%, rgba(46,219,250,0.14), transparent 55%), radial-gradient(80% 60% at 80% 100%, rgba(140,102,217,0.1), transparent 50%), linear-gradient(180deg, #0a0e16 0%, #06080d 100%)",
            }}
          />

          <div className="relative flex h-full flex-col px-[7%] pb-[8%] pt-[14%]">
            <motion.div {...stagger(0)} className="flex items-baseline justify-between">
              <span className="font-rounded text-[clamp(1.35rem,5.5vw,1.65rem)] font-light tracking-[-0.04em] text-white/88">
                {p.time}
              </span>
              <span className="text-[9px] font-semibold uppercase tracking-[0.18em] text-white/35">
                {p.today}
              </span>
            </motion.div>

            <motion.div {...stagger(1)} className="mt-[6%] flex justify-between gap-1">
              {p.rings.map((ring, i) => (
                <div key={ring.label} className="flex flex-1 flex-col items-center gap-0.5">
                  <ProgressRing
                    value={i === 0 ? 0.82 : i === 1 ? 0.68 : 0.74}
                    color={ringColors[ring.color as RingColorKey]}
                    size={46}
                    stroke={3.5}
                    center={i === 0 ? "82" : undefined}
                  />
                  <span className="text-[7px] font-semibold text-white/62">{ring.value}</span>
                  <span className="text-center text-[6.5px] font-medium leading-tight text-white/38">
                    {ring.label}
                  </span>
                </div>
              ))}
            </motion.div>

            <motion.div
              {...stagger(2)}
              className="mt-auto rounded-[14px] border border-white/[0.08] p-[5%]"
              style={{
                background:
                  "linear-gradient(155deg, rgba(140,102,217,0.22) 0%, rgba(255,255,255,0.04) 48%, rgba(255,255,255,0.02) 100%)",
                boxShadow: "0 16px 40px -16px rgba(140,102,217,0.35), inset 0 1px 0 rgba(255,255,255,0.08)",
              }}
            >
              <span
                className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[7px] font-bold uppercase tracking-[0.14em]"
                style={{
                  color: pillars.recovery,
                  background: `${pillars.recovery}18`,
                  border: `1px solid ${pillars.recovery}30`,
                }}
              >
                <span
                  className="h-1 w-1 rounded-full"
                  style={{ background: pillars.recovery, boxShadow: `0 0 6px ${pillars.recovery}` }}
                />
                {p.callLabel}
              </span>
              <p className="mt-2 font-rounded text-[clamp(1rem,4.2vw,1.2rem)] font-bold leading-[1.05] tracking-[-0.03em] text-white">
                {p.priority}
              </p>
              <p className="mt-2 text-[9px] font-semibold leading-snug text-white/88">
                {p.recommendation}
              </p>
              <p className="mt-1.5 text-[7.5px] leading-snug text-white/42">{p.rationale}</p>
            </motion.div>
          </div>

          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 mix-blend-screen"
            style={{
              background:
                "linear-gradient(135deg, rgba(255,255,255,0.12) 0%, rgba(255,255,255,0.02) 24%, transparent 46%)",
            }}
          />
        </div>
      </div>
    </div>
  );
}
