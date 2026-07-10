"use client";

import { useEffect, useState, type ReactNode } from "react";
import Image from "next/image";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { appleWatchUltra2, MOCKIFY_BASE_PATH } from "@/lib/device-frames";

interface HeroDeviceShowcaseProps {
  phoneSrc: string;
  phoneAlt: string;
  watchScreen: ReactNode;
  priority?: boolean;
}

function useDeviceWidths() {
  const [widths, setWidths] = useState({ phone: 380, watch: 168 });

  useEffect(() => {
    const update = () => {
      const phone = window.matchMedia("(max-width: 767px)").matches ? 280 : 380;
      setWidths({ phone, watch: Math.round(phone * 0.44) });
    };
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  return widths;
}

export default function HeroDeviceShowcase({
  phoneSrc,
  phoneAlt,
  watchScreen,
  priority,
}: HeroDeviceShowcaseProps) {
  const { phone, watch } = useDeviceWidths();

  return (
    <div className="hero-device-scene">
      <div aria-hidden className="hero-device-scene__ambient" />
      <div className="hero-device-scene__inner">
        <div className="hero-device-scene__phone">
          <DeviceMockup
            device={iPhone16Pro}
            color="Black Titanium"
            basePath={MOCKIFY_BASE_PATH}
            showStatusBar={false}
            width={phone}
            className="hero-device-mockup hero-device-mockup--phone"
          >
            <Image
              src={phoneSrc}
              alt={phoneAlt}
              width={900}
              height={1950}
              priority={priority}
              className="h-full w-full object-cover object-top"
            />
          </DeviceMockup>
        </div>

        <div className="hero-device-scene__watch">
          <DeviceMockup
            device={appleWatchUltra2}
            basePath={MOCKIFY_BASE_PATH}
            showStatusBar={false}
            width={watch}
            screenColor="#090a0e"
            className="hero-device-mockup hero-device-mockup--watch"
          >
            {watchScreen}
          </DeviceMockup>
        </div>
      </div>
      <div aria-hidden className="hero-device-scene__shadow" />
    </div>
  );
}
