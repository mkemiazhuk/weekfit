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
  premium?: boolean;
}

export default function PhoneMockup({
  src,
  alt,
  glow = pillars.recovery,
  className,
  priority,
  premium = false,
}: PhoneMockupProps) {
  return (
    <div className={clsx("relative", premium && "phone-mockup--premium", className)}>
      <div
        aria-hidden
        className="phone-glow"
        style={{
          background: `radial-gradient(closest-side, ${glow}${premium ? "55" : "44"}, transparent 70%)`,
        }}
      />
      <div className={clsx("phone-frame", premium && "phone-frame--premium")}>
        {premium && (
          <>
            <div aria-hidden className="phone-edge phone-edge--right" />
            <div aria-hidden className="phone-edge phone-edge--left" />
            <div aria-hidden className="phone-button phone-button--action" />
            <div aria-hidden className="phone-button phone-button--volume-up" />
            <div aria-hidden className="phone-button phone-button--volume-down" />
            <div aria-hidden className="phone-chassis-shine" />
          </>
        )}
        <div aria-hidden className={clsx("phone-island", premium && "phone-island--premium")} />
        <div className="phone-screen">
          <Image
            src={src}
            alt={alt}
            fill
            priority={priority}
            sizes="(max-width: 768px) 72vw, 480px"
            className="object-cover"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 mix-blend-screen"
            style={{
              background: premium
                ? "linear-gradient(128deg, rgba(255,255,255,0.22) 0%, rgba(255,255,255,0.05) 18%, transparent 44%)"
                : "linear-gradient(135deg, rgba(255,255,255,0.16) 0%, rgba(255,255,255,0.03) 22%, transparent 46%)",
            }}
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0"
            style={{ boxShadow: premium ? "inset 0 0 48px rgba(0,0,0,0.42)" : "inset 0 0 40px rgba(0,0,0,0.35)" }}
          />
        </div>
      </div>
    </div>
  );
}
