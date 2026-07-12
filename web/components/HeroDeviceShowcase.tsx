"use client";

import Image from "next/image";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";

interface HeroDeviceShowcaseProps {
  priority?: boolean;
}

/** Phone/watch widths are driven by CSS variables on `.hero-device-scene` (SSR-safe). */
const PHONE_RENDER_WIDTH = 380;

export default function HeroDeviceShowcase({
  priority,
}: HeroDeviceShowcaseProps) {
  return (
    <div className="hero-device-scene">
      <div aria-hidden className="hero-device-scene__fx">
        <div className="hero-device-scene__ambient" />
      </div>
      <div className="hero-device-scene__inner">
        <div className="hero-device-scene__phone">
          <DeviceMockup
            device={iPhone16Pro}
            color="Natural Titanium"
            basePath={MOCKIFY_BASE_PATH}
            showStatusBar={false}
            width={PHONE_RENDER_WIDTH}
            className="hero-device-mockup hero-device-mockup--phone"
          >
            <Image
              src="/img/today.webp"
              alt="WeekFit Today screen"
              width={900}
              height={1950}
              priority={priority}
              sizes="(max-width: 767px) 280px, 380px"
              className="h-full w-full object-cover object-top"
            />
          </DeviceMockup>
        </div>

        <div className="hero-device-scene__watch">
          <Image
            src="/img/hero-watch-ultra-overlay.png?v=4"
            alt=""
            aria-hidden
            width={434}
            height={716}
            sizes="(max-width: 767px) 136px, 184px"
            className="hero-device-mockup hero-device-mockup--watch"
            priority={priority}
          />
        </div>
      </div>
      <div aria-hidden className="hero-device-scene__shadow" />
    </div>
  );
}
