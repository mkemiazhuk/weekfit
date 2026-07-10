"use client";

import Image from "next/image";
import clsx from "clsx";
import { motion, useReducedMotion } from "framer-motion";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";
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

function parseWidth(sizes: string) {
  const n = Number.parseInt(sizes, 10);
  return Number.isFinite(n) ? n : 300;
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
  const width = parseWidth(sizes);

  return (
    <div className={clsx("journey-spotlight-phone device-scene-3d device-scene-3d--phone-only relative w-full", className)}>
      <div
        aria-hidden
        className="journey-spotlight-phone__ambient"
        style={{
          background: `radial-gradient(closest-side at 50% 42%, ${panel.accent}28, transparent 72%)`,
        }}
      />
      <div className="device-scene-3d__stage">
        <div className="device-scene-3d__phone">
          <DeviceMockup
            device={iPhone16Pro}
            color="Black Titanium"
            basePath={MOCKIFY_BASE_PATH}
            showStatusBar={false}
            width={width}
            className="device-mockup-frame device-mockup-frame--depth"
          >
            <div className="relative h-full w-full journey-spotlight-phone__screen">
              {panels.map((p, i) => (
                <Image
                  key={p.key}
                  src={p.screen}
                  alt={i === activeIndex ? p.screenAlt : ""}
                  fill
                  sizes={sizes}
                  className={clsx(
                    "object-cover object-top transition-opacity duration-700 ease-[cubic-bezier(0.22,1,0.36,1)]",
                    i === activeIndex ? "opacity-100" : "opacity-0"
                  )}
                />
              ))}

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
                    className="object-cover object-top"
                  />
                </div>
              </motion.div>

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
            </div>
          </DeviceMockup>
        </div>
      </div>
      <div aria-hidden className="device-scene-3d__shadow" />
    </div>
  );
}
