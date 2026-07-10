"use client";

import Image from "next/image";
import clsx from "clsx";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";

interface PhoneMockupProps {
  src: string;
  alt: string;
  className?: string;
  priority?: boolean;
  /** Render width in px — height follows device aspect ratio. */
  width?: number;
}

export default function PhoneMockup({
  src,
  alt,
  className,
  priority,
  width = 300,
}: PhoneMockupProps) {
  return (
    <DeviceMockup
      device={iPhone16Pro}
      color="Black Titanium"
      basePath={MOCKIFY_BASE_PATH}
      showStatusBar={false}
      width={width}
      className={clsx("mx-auto", className)}
    >
      <Image
        src={src}
        alt={alt}
        width={900}
        height={1950}
        priority={priority}
        sizes={`${width}px`}
        className="h-full w-full object-cover object-top"
      />
    </DeviceMockup>
  );
}
