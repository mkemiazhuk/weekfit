"use client";

import { motion, useReducedMotion } from "framer-motion";
import React from "react";
import { easeCalm } from "@/lib/motion";

interface PageHeroProps {
  kicker?: string;
  kickerColor?: string;
  title: string;
  lead?: string;
  children?: React.ReactNode;
}

export default function PageHero({
  kicker,
  kickerColor,
  title,
  lead,
  children,
}: PageHeroProps) {
  const reduce = useReducedMotion();
  const rise = (d: number) => ({
    initial: reduce ? { opacity: 1, y: 0 } : { opacity: 0, y: 22 },
    animate: { opacity: 1, y: 0 },
    transition: reduce ? { duration: 0 } : { duration: 0.8, ease: easeCalm, delay: d },
  });

  return (
    <section className="mx-auto max-w-3xl section-x pt-36 pb-12 text-center md:pt-44">
      {kicker && (
        <motion.span
          {...rise(0)}
          className={kickerColor ? "kicker" : "kicker text-brand"}
          style={kickerColor ? { color: kickerColor } : undefined}
        >
          {kicker}
        </motion.span>
      )}
      <motion.h1
        {...rise(0.06)}
        className="display mt-4 text-[clamp(2.4rem,6vw,4rem)] text-white"
      >
        {title}
      </motion.h1>
      {lead && (
        <motion.p {...rise(0.12)} className="body-lg mx-auto mt-6 max-w-[48ch]">
          {lead}
        </motion.p>
      )}
      {children && (
        <motion.div {...rise(0.18)} className="mt-10">
          {children}
        </motion.div>
      )}
    </section>
  );
}
