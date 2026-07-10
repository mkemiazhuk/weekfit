"use client";

import type { ReactNode } from "react";
import { appleWatchUltra2, MOCKIFY_BASE_PATH } from "@/lib/device-frames";

interface WatchMockupProps {
  children: ReactNode;
  className?: string;
  width?: number;
}

/** Apple Watch frame with an opaque screen panel sized to the PNG cutout. */
export default function WatchMockup({ children, className = "", width = 172 }: WatchMockupProps) {
  const device = appleWatchUltra2;
  const frameH = width * (device.framePngHeight / device.framePngWidth);
  const screenLeft = width * device.screenLeftFraction;
  const screenTop = frameH * device.screenTopFraction;
  const screenW = width * device.screenWidthFraction;
  const screenH = frameH * device.screenHeightFraction;
  const screenRadius = width * device.screenRadiusFraction;

  return (
    <div
      className={className}
      style={{
        position: "relative",
        width,
        height: frameH,
        isolation: "isolate",
      }}
    >
      <div aria-hidden className="watch-mockup__backplate" />
      <div
        className="watch-mockup__screen"
        style={{
          position: "absolute",
          left: screenLeft,
          top: screenTop,
          width: screenW,
          height: screenH,
          borderRadius: screenRadius,
        }}
      >
        {children}
      </div>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={`${MOCKIFY_BASE_PATH}${device.frameSrc}`}
        alt=""
        draggable={false}
        className="watch-mockup__frame"
      />
    </div>
  );
}
