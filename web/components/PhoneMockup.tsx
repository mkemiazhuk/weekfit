"use client";

import Image from "next/image";
import clsx from "clsx";
import { pillars } from "@/lib/tokens";

interface PhoneMockupProps {
  src: string;
  alt: string;
  glow?: string;
  className?: string;
  priority?: boolean;
  hero?: boolean;
}

export default function PhoneMockup({
  src,
  alt,
  glow = pillars.recovery,
  className,
  priority,
  hero = false,
}: PhoneMockupProps) {
  return (
    <div className={clsx("relative", className)}>
      <div
        aria-hidden
        className={clsx("phone-glow", hero && "phone-glow--hero")}
        style={{
          background: `radial-gradient(closest-side, ${glow}36, transparent 72%)`,
        }}
      />
      <div className={clsx("phone-frame", hero && "phone-frame--hero")}>
        <div aria-hidden className="phone-island" />
        <div className="phone-screen">
          <Image
            src={src}
            alt={alt}
            fill
            priority={priority}
            sizes={hero ? "(max-width: 768px) 72vw, 420px" : "(max-width: 768px) 70vw, 320px"}
            className="object-cover"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 mix-blend-screen"
            style={{
              background:
                "linear-gradient(135deg, rgba(255,255,255,0.14) 0%, rgba(255,255,255,0.025) 24%, transparent 48%)",
            }}
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0"
            style={{ boxShadow: "inset 0 0 36px rgba(0,0,0,0.32)" }}
          />
        </div>
      </div>
    </div>
  );
}
