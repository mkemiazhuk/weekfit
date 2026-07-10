"use client";

import type { ReactNode } from "react";
import Image from "next/image";
import clsx from "clsx";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";

interface PhoneMockupProps {
  src?: string;
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
  src,
  alt = "",
  children,
  className,
  priority,
  width = 300,
  depth = false,
}: PhoneMockupProps) {
  const screen = children ?? (
    src ? (
      <Image
        src={src}
        alt={alt}
        width={900}
        height={1950}
        priority={priority}
        sizes={`${width}px`}
        className="h-full w-full object-cover object-top"
      />
    ) : null
  );

  const mockup = (
    <DeviceMockup
      device={iPhone16Pro}
      color="Black Titanium"
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
