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
    <div className="hero-device-scene device-scene-3d">
      <div aria-hidden className="hero-device-scene__ambient" />
      <div className="hero-device-scene__inner device-scene-3d__stage">
        <div className="hero-device-scene__phone device-scene-3d__phone">
          <DeviceMockup
            device={iPhone16Pro}
            color="Black Titanium"
            basePath={MOCKIFY_BASE_PATH}
            showStatusBar={false}
            width={phone}
            className="device-mockup-frame device-mockup-frame--depth"
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
          <div aria-hidden className="device-scene-3d__phone-shine" />
        </div>

        <div className="hero-device-scene__watch device-scene-3d__watch">
          <DeviceMockup
            device={appleWatchUltra2}
            basePath={MOCKIFY_BASE_PATH}
            showStatusBar={false}
            width={watch}
            screenColor="#090a0e"
            className="device-mockup-frame device-mockup-frame--watch"
          >
            {watchScreen}
          </DeviceMockup>
        </div>
      </div>
      <div aria-hidden className="hero-device-scene__shadow device-scene-3d__shadow" />
    </div>
  );
}
