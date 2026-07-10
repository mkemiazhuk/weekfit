"use client";

import Image from "next/image";
import { useEffect, useState, type ReactNode } from "react";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";
import WatchMockup from "./WatchMockup";

interface HeroDeviceShowcaseProps {
  watchScreen: ReactNode;
  priority?: boolean;
}

function useDeviceWidths() {
  const [widths, setWidths] = useState({ phone: 380, watch: 172 });

  useEffect(() => {
    const update = () => {
      const phone = window.matchMedia("(max-width: 767px)").matches ? 280 : 380;
      setWidths({ phone, watch: Math.round(phone * 0.45) });
    };
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  return widths;
}

export default function HeroDeviceShowcase({
  watchScreen,
  priority,
}: HeroDeviceShowcaseProps) {
  const { phone, watch } = useDeviceWidths();

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
            width={phone}
            className="hero-device-mockup hero-device-mockup--phone"
          >
            <Image
              src="/img/today.jpg"
              alt="WeekFit Today screen"
              width={900}
              height={1950}
              priority={priority}
              className="h-full w-full object-cover object-top"
            />
          </DeviceMockup>
        </div>

        <div className="hero-device-scene__watch">
          <WatchMockup width={watch} className="hero-device-mockup hero-device-mockup--watch">
            {watchScreen}
          </WatchMockup>
        </div>
      </div>
      <div aria-hidden className="hero-device-scene__shadow" />
    </div>
  );
}
