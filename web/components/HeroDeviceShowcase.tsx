"use client";

import type { ReactNode } from "react";
import PhoneMockup from "./PhoneMockup";
import WatchMockup from "./WatchMockup";

interface HeroDeviceShowcaseProps {
  phoneSrc: string;
  phoneAlt: string;
  phoneGlow?: string;
  watchGlow?: string;
  watchScreen: ReactNode;
  priority?: boolean;
}

export default function HeroDeviceShowcase({
  phoneSrc,
  phoneAlt,
  phoneGlow,
  watchGlow,
  watchScreen,
  priority,
}: HeroDeviceShowcaseProps) {
  return (
    <div className="hero-device-scene">
      <div aria-hidden className="hero-device-scene__ambient" />
      <div className="hero-device-scene__inner">
        <div className="hero-device-scene__phone">
          <div className="hero-product-stage">
            <PhoneMockup
              src={phoneSrc}
              alt={phoneAlt}
              glow={phoneGlow}
              premium
              priority={priority}
            />
            <div aria-hidden className="hero-product-reflection" />
          </div>
        </div>

        <div className="hero-device-scene__watch">
          <div className="hero-watch-stage">
            <WatchMockup glow={watchGlow} premium>
              {watchScreen}
            </WatchMockup>
            <div aria-hidden className="hero-watch-reflection" />
          </div>
        </div>
      </div>
      <div aria-hidden className="hero-device-scene__shadow" />
    </div>
  );
}
