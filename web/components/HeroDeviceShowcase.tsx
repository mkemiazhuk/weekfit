"use client";

import Image from "next/image";
import { useLayoutEffect, useState, type CSSProperties } from "react";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";
import {
  WATCH_OVERLAY_VERSION,
  watchOverlayDimensions,
  watchOverlayPath,
  watchVariantForWidth,
} from "@/lib/responsive-images";
import ScreenShotImage from "@/components/ScreenShotImage";

interface HeroDeviceShowcaseProps {
  priority?: boolean;
}

function readDeviceWidths() {
  const phone = window.matchMedia("(max-width: 767px)").matches ? 280 : 380;
  return { phone, watch: Math.round(phone * 0.485) };
}

export default function HeroDeviceShowcase({
  priority,
}: HeroDeviceShowcaseProps) {
  const [widths, setWidths] = useState({ phone: 280, watch: 136 });

  useLayoutEffect(() => {
    const update = () => setWidths(readDeviceWidths());
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  const { phone, watch } = widths;
  const watchVariant = watchVariantForWidth(watch);
  const watchDims = watchOverlayDimensions(watchVariant);

  const sceneStyle = {
    "--watch-w": `${watch}px`,
  } as CSSProperties;

  return (
    <div className="hero-device-scene">
      <div aria-hidden className="hero-device-scene__fx">
        <div className="hero-device-scene__ambient" />
      </div>
      <div className="hero-device-scene__inner" style={sceneStyle}>
        <div className="hero-device-scene__phone">
          <DeviceMockup
            device={iPhone16Pro}
            color="Natural Titanium"
            basePath={MOCKIFY_BASE_PATH}
            showStatusBar={false}
            width={phone}
            className="hero-device-mockup hero-device-mockup--phone"
          >
            <ScreenShotImage
              name="today"
              alt="WeekFit Today screen"
              phoneWidthPx={phone}
              priority={priority}
              loading="eager"
              sizes="(max-width: 767px) 280px, 380px"
              className="h-full w-full object-cover object-top"
            />
          </DeviceMockup>
        </div>

        <div aria-hidden className="hero-device-scene__watch-slot-mask" />

        <div className="hero-device-scene__watch">
          <Image
            src={`${watchOverlayPath(watchVariant)}?v=${WATCH_OVERLAY_VERSION}`}
            alt=""
            aria-hidden
            width={watchDims.width}
            height={watchDims.height}
            sizes={`${watch}px`}
            style={{ width: watch, height: "auto" }}
            className="hero-device-mockup hero-device-mockup--watch"
            priority={priority}
            loading="eager"
          />
        </div>
      </div>
      <div aria-hidden className="hero-device-scene__shadow" />
    </div>
  );
}
