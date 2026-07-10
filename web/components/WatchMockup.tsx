"use client";

import clsx from "clsx";
import { pillars } from "@/lib/tokens";

interface WatchMockupProps {
  glow?: string;
  className?: string;
  children: React.ReactNode;
  premium?: boolean;
}

export default function WatchMockup({
  glow = pillars.coach,
  className,
  children,
  premium = false,
}: WatchMockupProps) {
  return (
    <div className={clsx("relative", premium && "watch-mockup--premium", className)}>
      <div
        aria-hidden
        className="watch-glow"
        style={{
          background: `radial-gradient(closest-side, ${glow}${premium ? "50" : "44"}, transparent 70%)`,
        }}
      />
      <div className={clsx("watch-frame", premium && "watch-frame--premium")}>
        {premium && (
          <>
            <div aria-hidden className="watch-band watch-band--top" />
            <div aria-hidden className="watch-band watch-band--bottom" />
            <div aria-hidden className="watch-edge watch-edge--right" />
            <div aria-hidden className="watch-edge watch-edge--left" />
            <div aria-hidden className="watch-chassis-shine" />
          </>
        )}
        <div aria-hidden className={clsx("watch-crown", premium && "watch-crown--premium")} />
        {premium && <div aria-hidden className="watch-crown-ring" />}
        <div aria-hidden className={clsx("watch-side-button", premium && "watch-side-button--premium")} />
        <div className="watch-screen">
          {children}
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 mix-blend-screen"
            style={{
              background: premium
                ? "linear-gradient(128deg, rgba(255,255,255,0.2) 0%, rgba(255,255,255,0.04) 20%, transparent 46%)"
                : "linear-gradient(135deg, rgba(255,255,255,0.16) 0%, rgba(255,255,255,0.03) 22%, transparent 46%)",
            }}
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0"
            style={{ boxShadow: premium ? "inset 0 0 32px rgba(0,0,0,0.48)" : "inset 0 0 28px rgba(0,0,0,0.42)" }}
          />
        </div>
      </div>
    </div>
  );
}
