"use client";

import { motion, useReducedMotion } from "framer-motion";
import React from "react";
import { easeCalm, durationReveal } from "@/lib/motion";

interface RevealProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  y?: number;
  as?: "div" | "span" | "section" | "li";
}

export default function Reveal({
  children,
  className,
  delay = 0,
  y = 16,
}: RevealProps) {
  const reduce = useReducedMotion();
  const shown = { opacity: 1, y: 0 };
  return (
    <motion.div
      className={className}
      initial={reduce ? shown : { opacity: 0, y }}
      whileInView={shown}
      viewport={{ once: true, margin: "-10% 0px -10% 0px" }}
      transition={
        reduce ? { duration: 0 } : { duration: durationReveal, ease: easeCalm, delay }
      }
    >
      {children}
    </motion.div>
  );
}
