"use client";

import Image from "next/image";
import { useEffect, useState, type ComponentType, type CSSProperties, type ReactNode } from "react";
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

type DeviceMockupProps = {
  device: unknown;
  color: string;
  basePath: string;
  showStatusBar: boolean;
  width: number;
  className?: string;
  children: ReactNode;
};

type MockifyBundle = {
  DeviceMockup: ComponentType<DeviceMockupProps>;
  iPhone16Pro: unknown;
};

function useDeviceWidths() {
  const [widths, setWidths] = useState({ phone: 380, watch: 184 });

  useEffect(() => {
    const update = () => {
      const phone = window.matchMedia("(max-width: 767px)").matches ? 280 : 380;
      setWidths({ phone, watch: Math.round(phone * 0.485) });
    };
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  return widths;
}

export default function HeroDeviceShowcase({
  priority,
}: HeroDeviceShowcaseProps) {
  const { phone, watch } = useDeviceWidths();
  const watchVariant = watchVariantForWidth(watch);
  const watchDims = watchOverlayDimensions(watchVariant);
  const [mockify, setMockify] = useState<MockifyBundle | null>(null);

  useEffect(() => {
    const load = () => {
      void import("@mockifydev/react").then((mod) => {
        setMockify({
          DeviceMockup: mod.DeviceMockup as ComponentType<DeviceMockupProps>,
          iPhone16Pro: mod.iPhone16Pro,
        });
      });
    };

    if (typeof window.requestIdleCallback === "function") {
      const id = window.requestIdleCallback(load, { timeout: 2200 });
      return () => window.cancelIdleCallback(id);
    }

    const timer = window.setTimeout(load, 120);
    return () => window.clearTimeout(timer);
  }, []);

  const sceneStyle = {
    "--watch-w": `${watch}px`,
  } as CSSProperties;

  const screen = (
    <ScreenShotImage
      name="today"
      alt="WeekFit Today screen"
      phoneWidthPx={phone}
      priority={priority}
      sizes="(max-width: 767px) 280px, 380px"
      className="h-full w-full object-cover object-top"
    />
  );

  return (
    <div className="hero-device-scene">
      <div aria-hidden className="hero-device-scene__fx">
        <div className="hero-device-scene__ambient" />
      </div>
      <div className="hero-device-scene__inner" style={sceneStyle}>
        <div className="hero-device-scene__phone">
          {mockify ? (
            <mockify.DeviceMockup
              device={mockify.iPhone16Pro}
              color="Natural Titanium"
              basePath={MOCKIFY_BASE_PATH}
              showStatusBar={false}
              width={phone}
              className="hero-device-mockup hero-device-mockup--phone"
            >
              {screen}
            </mockify.DeviceMockup>
          ) : (
            <div className="hero-device-lcp-phone mx-auto" style={{ width: phone }}>
              {screen}
            </div>
          )}
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
          />
        </div>
      </div>
      <div aria-hidden className="hero-device-scene__shadow" />
    </div>
  );
}
