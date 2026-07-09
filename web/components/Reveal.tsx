"use client";

import { motion, useReducedMotion } from "framer-motion";
import React from "react";
import { easeCalm } from "@/lib/motion";

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
  y = 24,
}: RevealProps) {
  const reduce = useReducedMotion();
  const shown = { opacity: 1, y: 0 };
  return (
    <motion.div
      className={className}
      initial={reduce ? shown : { opacity: 0, y }}
      whileInView={shown}
      viewport={{ once: true, margin: "-12% 0px -12% 0px" }}
      transition={
        reduce ? { duration: 0 } : { duration: 0.8, ease: easeCalm, delay }
      }
    >
      {children}
    </motion.div>
  );
}
