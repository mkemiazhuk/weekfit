"use client";

import { motion, useReducedMotion } from "framer-motion";
import clsx from "clsx";
import { easeReveal, durationRevealSlow } from "@/lib/motion";

interface TextRevealProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  as?: "h1" | "h2" | "p" | "span";
}

export default function TextReveal({
  children,
  className,
  delay = 0,
  as: Tag = "span",
}: TextRevealProps) {
  const reduce = useReducedMotion();

  if (reduce) {
    return <Tag className={className}>{children}</Tag>;
  }

  return (
    <Tag className={clsx("block overflow-hidden", className)}>
      <motion.span
        className="block"
        initial={{ opacity: 0, y: "108%" }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: durationRevealSlow, ease: easeReveal, delay }}
      >
        {children}
      </motion.span>
    </Tag>
  );
}
