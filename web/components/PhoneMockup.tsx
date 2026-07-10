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
}

export default function PhoneMockup({
  src,
  alt,
  glow = pillars.recovery,
  className,
  priority,
}: PhoneMockupProps) {
  return (
    <div className={clsx("relative", className)}>
      <div
        aria-hidden
        className="phone-glow"
        style={{
          background: `radial-gradient(closest-side, ${glow}44, transparent 70%)`,
        }}
      />
      <div className="phone-frame">
        <div aria-hidden className="phone-island" />
        <div className="phone-screen">
          <Image
            src={src}
            alt={alt}
            fill
            priority={priority}
            sizes="(max-width: 768px) 70vw, 320px"
            className="object-cover"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 mix-blend-screen"
            style={{
              background:
                "linear-gradient(135deg, rgba(255,255,255,0.16) 0%, rgba(255,255,255,0.03) 22%, transparent 46%)",
            }}
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0"
            style={{ boxShadow: "inset 0 0 40px rgba(0,0,0,0.35)" }}
          />
        </div>
      </div>
    </div>
  );
}
