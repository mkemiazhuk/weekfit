"use client";

import { useLayoutEffect, useState } from "react";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";
import AppScreen from "@/components/AppScreen";

interface HeroDeviceShowcaseProps {
  priority?: boolean;
}

function readPhoneWidth() {
  return window.matchMedia("(max-width: 767px)").matches ? 248 : 292;
}

export default function HeroDeviceShowcase({ priority }: HeroDeviceShowcaseProps) {
  const [phone, setPhone] = useState(248);

  useLayoutEffect(() => {
    const update = () => setPhone(readPhoneWidth());
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  return (
    <div className="hero-device-scene hero-device-scene--solo">
      <DeviceMockup
        device={iPhone16Pro}
        color="Natural Titanium"
        basePath={MOCKIFY_BASE_PATH}
        showStatusBar={false}
        width={phone}
        className="hero-device-mockup hero-device-mockup--phone"
      >
        <div className="h-full w-full">
          <AppScreen variant="today" priority={priority} />
        </div>
      </DeviceMockup>
    </div>
  );
}
