"use client";

import Image from "next/image";
import { motion, useReducedMotion } from "framer-motion";
import { pillars } from "@/lib/tokens";
import { spotlightImagePosition } from "@/lib/journeySpotlights";

/** Spotlight window over the Up Next → Core card on the Today screen. */
const CORE_REGION = {
  top: 36.4,
  left: 4.5,
  width: 91,
  height: 11.6,
  radius: 18,
};

interface HeroPhoneLaunchScreenProps {
  priority?: boolean;
  badgeLabel: string;
}

export default function HeroPhoneLaunchScreen({ priority, badgeLabel }: HeroPhoneLaunchScreenProps) {
  const reduce = useReducedMotion();
  const imgPos = spotlightImagePosition(CORE_REGION);

  return (
    <div className="hero-phone-launch relative h-full w-full">
      <Image
        src="/img/today.jpg"
        alt="WeekFit Today with Core training ready to start"
        width={900}
        height={1950}
        priority={priority}
        className="h-full w-full object-cover object-top"
      />

      <div aria-hidden className="hero-phone-launch__dim" />

      <motion.div
        aria-hidden
        className="hero-phone-launch__lift"
        style={{
          top: `${CORE_REGION.top}%`,
          left: `${CORE_REGION.left}%`,
          width: `${CORE_REGION.width}%`,
          height: `${CORE_REGION.height}%`,
          borderRadius: CORE_REGION.radius,
        }}
        animate={
          reduce
            ? undefined
            : {
                filter: [
                  "brightness(1.12) saturate(1.08)",
                  "brightness(1.22) saturate(1.12)",
                  "brightness(1.12) saturate(1.08)",
                ],
                scale: [1, 1.018, 1],
              }
        }
        transition={{ duration: 2.2, repeat: Infinity, ease: "easeInOut" }}
      >
        <Image
          src="/img/today.jpg"
          alt=""
          width={900}
          height={1950}
          className="absolute object-cover object-top"
          style={imgPos}
        />
      </motion.div>

      <motion.div
        aria-hidden
        className="hero-phone-launch__ring"
        style={{
          top: `${CORE_REGION.top}%`,
          left: `${CORE_REGION.left}%`,
          width: `${CORE_REGION.width}%`,
          height: `${CORE_REGION.height}%`,
          borderRadius: CORE_REGION.radius,
          "--launch-accent": pillars.activity,
        } as React.CSSProperties}
        animate={reduce ? undefined : { opacity: [0.72, 1, 0.72] }}
        transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
      />

      <div aria-hidden className="hero-phone-launch__badge">
        {badgeLabel}
      </div>
    </div>
  );
}
