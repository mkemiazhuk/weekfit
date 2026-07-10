"use client";

import Image from "next/image";
import clsx from "clsx";
import { motion, useReducedMotion } from "framer-motion";
import { springSoft } from "@/lib/motion";
import {
  journeyPanelSpotlights,
  spotlightImagePosition,
  type SpotlightRegion,
} from "@/lib/journeySpotlights";

interface PanelScreen {
  key: string;
  screen: string;
  screenAlt: string;
  accent: string;
}

interface JourneySpotlightPhoneProps {
  panels: PanelScreen[];
  activeIndex: number;
  className?: string;
  sizes?: string;
}

export default function JourneySpotlightPhone({
  panels,
  activeIndex,
  className,
  sizes = "320px",
}: JourneySpotlightPhoneProps) {
  const reduce = useReducedMotion();
  const panel = panels[activeIndex];
  const region: SpotlightRegion = journeyPanelSpotlights[panel.key] ?? journeyPanelSpotlights.morning;
  const imgPos = spotlightImagePosition(region);
  const transition = reduce ? { duration: 0 } : springSoft;

  return (
    <div className={clsx("journey-spotlight-phone relative w-full", className)}>
      <div
        aria-hidden
        className="phone-glow phone-glow--hero transition-all duration-700"
        style={{
          background: `radial-gradient(closest-side, ${panel.accent}30, transparent 72%)`,
        }}
      />
      <div
        className="phone-frame phone-frame--hero transition-shadow duration-700"
        style={{
          boxShadow: `0 56px 120px -32px rgba(0,0,0,0.78), 0 0 44px -22px ${panel.accent}30`,
        }}
      >
        <div aria-hidden className="phone-island" />
        <div className="phone-screen journey-spotlight-phone__screen">
          {panels.map((p, i) => (
            <Image
              key={p.key}
              src={p.screen}
              alt={i === activeIndex ? p.screenAlt : ""}
              fill
              sizes={sizes}
              className={clsx(
                "object-cover transition-opacity duration-700 ease-[cubic-bezier(0.22,1,0.36,1)]",
                i === activeIndex ? "opacity-100" : "opacity-0"
              )}
            />
          ))}

          {/* Brighter lifted layer aligned to the spotlight window */}
          <motion.div
            aria-hidden
            className="journey-spotlight-phone__lift"
            animate={{
              top: `${region.top}%`,
              left: `${region.left}%`,
              width: `${region.width}%`,
              height: `${region.height}%`,
              borderRadius: region.radius ?? 14,
            }}
            transition={transition}
          >
            <div className="absolute" style={imgPos}>
              <Image
                key={panel.key}
                src={panel.screen}
                alt=""
                fill
                sizes={sizes}
                className="object-cover"
              />
            </div>
          </motion.div>

          {/* Dim + soft accent ring */}
          <motion.div
            aria-hidden
            className="journey-spotlight-phone__cutout"
            animate={{
              top: `${region.top}%`,
              left: `${region.left}%`,
              width: `${region.width}%`,
              height: `${region.height}%`,
              borderRadius: region.radius ?? 14,
            }}
            transition={transition}
            style={{ "--spotlight-accent": panel.accent } as React.CSSProperties}
          />

          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 z-[5] mix-blend-screen"
            style={{
              background:
                "linear-gradient(135deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.02) 24%, transparent 48%)",
            }}
          />
        </div>
      </div>
    </div>
  );
}
