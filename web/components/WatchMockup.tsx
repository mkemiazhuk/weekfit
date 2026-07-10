"use client";

import clsx from "clsx";
import { pillars } from "@/lib/tokens";

interface WatchMockupProps {
  glow?: string;
  className?: string;
  children: React.ReactNode;
}

export default function WatchMockup({
  glow = pillars.coach,
  className,
  children,
}: WatchMockupProps) {
  return (
    <div className={clsx("relative", className)}>
      <div
        aria-hidden
        className="watch-glow"
        style={{
          background: `radial-gradient(closest-side, ${glow}44, transparent 70%)`,
        }}
      />
      <div className="watch-frame">
        <div aria-hidden className="watch-crown" />
        <div aria-hidden className="watch-side-button" />
        <div className="watch-screen">
          {children}
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
            style={{ boxShadow: "inset 0 0 28px rgba(0,0,0,0.42)" }}
          />
        </div>
      </div>
    </div>
  );
}
