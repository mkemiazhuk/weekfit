"use client";

import { motion, useReducedMotion } from "framer-motion";
import ProgressRing from "../ProgressRing";
import { pillars } from "@/lib/tokens";

/** Mini readiness rings that animate in over the hero phone. */
export default function HeroRings() {
  const reduce = useReducedMotion();

  const rings = [
    { value: 0.81, color: pillars.recovery, label: "81%", delay: 0.9 },
    { value: 0.65, color: pillars.activity, label: "65%", delay: 1.05 },
    { value: 0.74, color: pillars.nutrition, label: "74%", delay: 1.2 },
  ];

  return (
    <motion.div
      className="pointer-events-none absolute -left-3 top-[18%] z-10 flex flex-col gap-2 md:-left-6"
      initial={reduce ? { opacity: 1 } : { opacity: 0, x: -12 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1], delay: 0.85 }}
    >
      {rings.map((ring) => (
        <motion.div
          key={ring.label}
          className="glass rounded-2xl p-2 shadow-lg"
          initial={reduce ? {} : { opacity: 0, scale: 0.85 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1], delay: ring.delay }}
        >
          <ProgressRing
            value={ring.value}
            color={ring.color}
            size={52}
            stroke={5}
            center={ring.label}
          />
        </motion.div>
      ))}
    </motion.div>
  );
}
