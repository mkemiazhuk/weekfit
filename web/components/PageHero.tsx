"use client";

import { motion, useReducedMotion } from "framer-motion";
import React from "react";

interface PageHeroProps {
  kicker?: string;
  kickerColor?: string;
  title: string;
  lead?: string;
  children?: React.ReactNode;
}

export default function PageHero({
  kicker,
  kickerColor = "#66f070",
  title,
  lead,
  children,
}: PageHeroProps) {
  const reduce = useReducedMotion();
  const rise = (d: number) => ({
    initial: reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 22 },
    animate: { opacity: 1, y: 0 },
    transition: reduce
      ? { duration: 0 }
      : { duration: 0.8, ease: [0.22, 1, 0.36, 1] as const, delay: d },
  });

  return (
    <section className="mx-auto max-w-3xl px-6 pt-36 pb-10 text-center md:pt-44">
      {kicker && (
        <motion.span
          {...rise(0)}
          className="text-[13px] font-bold uppercase tracking-[0.18em]"
          style={{ color: kickerColor }}
        >
          {kicker}
        </motion.span>
      )}
      <motion.h1
        {...rise(0.06)}
        className="display mt-3 text-[clamp(2.4rem,6vw,4rem)] text-white"
      >
        {title}
      </motion.h1>
      {lead && (
        <motion.p
          {...rise(0.12)}
          className="mx-auto mt-5 max-w-[54ch] text-[clamp(1.05rem,2vw,1.22rem)] leading-relaxed text-white/60"
        >
          {lead}
        </motion.p>
      )}
      {children && (
        <motion.div {...rise(0.18)} className="mt-8">
          {children}
        </motion.div>
      )}
    </section>
  );
}
