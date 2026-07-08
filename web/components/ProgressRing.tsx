"use client";

import { motion, useReducedMotion } from "framer-motion";

interface ProgressRingProps {
  value: number; // 0..1
  color: string;
  size?: number;
  stroke?: number;
  label?: string;
  center?: string; // e.g. "81%"
  className?: string;
}

// Apple Activity–style ring: 12 o'clock start, clockwise, round caps,
// soft tip glow, faint track. Draws when scrolled into view.
export default function ProgressRing({
  value,
  color,
  size = 120,
  stroke = 8,
  label,
  center,
  className,
}: ProgressRingProps) {
  const reduce = useReducedMotion();
  const r = (size - stroke) / 2;
  const c = size / 2;
  const clamped = Math.max(0, Math.min(1, value));

  return (
    <div
      className={className}
      style={{ width: size, height: size, position: "relative" }}
    >
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        style={{ transform: "rotate(-90deg)" }}
      >
        <circle
          cx={c}
          cy={c}
          r={r}
          fill="none"
          stroke="rgba(255,255,255,0.11)"
          strokeWidth={stroke}
        />
        <motion.circle
          cx={c}
          cy={c}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          pathLength={1}
          strokeDasharray={1}
          initial={reduce ? { strokeDashoffset: 1 - clamped } : { strokeDashoffset: 1 }}
          whileInView={{ strokeDashoffset: 1 - clamped }}
          viewport={{ once: true, margin: "-10%" }}
          transition={{ duration: 1.3, ease: [0.22, 1, 0.36, 1], delay: 0.1 }}
          style={{ filter: `drop-shadow(0 0 6px ${color}66)` }}
        />
      </svg>
      {(center || label) && (
        <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
          {center && (
            <span
              className="font-rounded font-bold leading-none"
              style={{ fontSize: size * 0.24 }}
            >
              {center}
            </span>
          )}
          {label && (
            <span
              className="font-rounded uppercase tracking-[0.14em] text-white/45"
              style={{ fontSize: Math.max(8, size * 0.075), marginTop: 4 }}
            >
              {label}
            </span>
          )}
        </div>
      )}
    </div>
  );
}
