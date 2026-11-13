"use client";

import type { ReactNode } from "react";
import clsx from "clsx";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";
import AppScreen, { appScreenForKey } from "./AppScreen";
import type { ScreenImageKey } from "@/lib/screen-images";

interface PhoneMockupProps {
  src?: string;
  screenKey?: ScreenImageKey;
  alt?: string;
  children?: ReactNode;
  className?: string;
  priority?: boolean;
  /** Render width in px — height follows device aspect ratio. */
  width?: number;
  /** Subtle 3/4 perspective tilt (product-shot depth). */
  depth?: boolean;
}

export default function PhoneMockup({
  screenKey = "today",
  alt = "",
  children,
  className,
  width = 300,
  depth = false,
}: PhoneMockupProps) {
  const screen = children ?? (
    <div className="h-full w-full" role="img" aria-label={alt}>
      <AppScreen variant={appScreenForKey(screenKey)} />
    </div>
  );

  const mockup = (
    <DeviceMockup
      device={iPhone16Pro}
      color="Natural Titanium"
      basePath={MOCKIFY_BASE_PATH}
      showStatusBar={false}
      width={width}
      className={clsx("device-mockup-frame", depth && "device-mockup-frame--depth", className)}
    >
      {screen}
    </DeviceMockup>
  );

  if (!depth) return mockup;

  return (
    <div className="device-scene-3d device-scene-3d--phone-only">
      <div className="device-scene-3d__stage">
        <div className="device-scene-3d__phone">{mockup}</div>
      </div>
      <div aria-hidden className="device-scene-3d__shadow" />
    </div>
  );
}
