"use client";

import Image from "next/image";
import clsx from "clsx";
import { motion, useReducedMotion } from "framer-motion";
import { springSoft } from "@/lib/motion";
import type { JourneySpotlightStep } from "@/lib/journeySpotlight";

interface JourneySpotlightPhoneProps {
  steps: JourneySpotlightStep[];
  activeIndex: number;
  className?: string;
  sizes?: string;
}

export default function JourneySpotlightPhone({
  steps,
  activeIndex,
  className,
  sizes = "320px",
}: JourneySpotlightPhoneProps) {
  const reduce = useReducedMotion();
  const step = steps[activeIndex];
  const screens = [...new Set(steps.map((s) => s.screen))];

  const transition = reduce ? { duration: 0 } : springSoft;

  return (
    <div className={clsx("journey-spotlight-phone relative w-full", className)}>
      <div
        aria-hidden
        className="phone-glow transition-all duration-700"
        style={{
          background: `radial-gradient(closest-side, ${step.accent}32, transparent 72%)`,
          filter: "blur(40px)",
        }}
      />
      <div
        className="phone-frame phone-frame--hero transition-shadow duration-700"
        style={{
          boxShadow: `0 56px 120px -32px rgba(0,0,0,0.78), 0 0 48px -24px ${step.accent}28`,
        }}
      >
        <div aria-hidden className="phone-island" />
        <div className="phone-screen journey-spotlight-phone__screen">
          {screens.map((src) => (
            <Image
              key={src}
              src={src}
              alt={step.screenAlt}
              fill
              sizes={sizes}
              className={clsx(
                "object-cover transition-opacity duration-700 ease-[cubic-bezier(0.22,1,0.36,1)]",
                src === step.screen ? "opacity-100" : "opacity-0"
              )}
            />
          ))}

          <div aria-hidden className="journey-spotlight-phone__dim" />

          <motion.div
            aria-hidden
            className="journey-spotlight-phone__cutout"
            animate={{
              top: `${step.region.top}%`,
              left: `${step.region.left}%`,
              width: `${step.region.width}%`,
              height: `${step.region.height}%`,
            }}
            transition={transition}
            style={
              {
                borderRadius: step.region.radius ?? 14,
                "--spotlight-accent": step.accent,
              } as React.CSSProperties
            }
          />

          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 mix-blend-screen"
            style={{
              background:
                "linear-gradient(135deg, rgba(255,255,255,0.12) 0%, rgba(255,255,255,0.02) 24%, transparent 48%)",
            }}
          />
        </div>
      </div>
    </div>
  );
}
