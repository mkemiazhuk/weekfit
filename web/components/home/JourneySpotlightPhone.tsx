"use client";

import { useEffect, useRef, useState } from "react";
import clsx from "clsx";
import { DeviceMockup, iPhone16Pro } from "@mockifydev/react";
import { MOCKIFY_BASE_PATH } from "@/lib/device-frames";
import AppScreen, { appScreenForJourney } from "../AppScreen";

interface PanelScreen {
  key: string;
  screen: string;
  screenAlt: string;
  accent: string;
}

interface JourneySpotlightPhoneProps {
  panels: PanelScreen[];
  activeIndex: number;
  className?: string;
  sizes?: string;
}

function parseWidth(sizes: string) {
  const n = Number.parseInt(sizes, 10);
  return Number.isFinite(n) ? n : 300;
}

export default function JourneySpotlightPhone({
  panels,
  activeIndex,
  className,
  sizes = "320px",
}: JourneySpotlightPhoneProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const [inView, setInView] = useState(false);
  const panel = panels[activeIndex];
  const width = parseWidth(sizes);

  useEffect(() => {
    const el = rootRef.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      ([entry]) => setInView(entry.isIntersecting),
      { rootMargin: "240px 0px 240px 0px", threshold: 0 }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div
      ref={rootRef}
      className={clsx("journey-spotlight-phone device-scene-3d device-scene-3d--phone-only relative w-full", className)}
    >
      <div
        aria-hidden
        className="journey-spotlight-phone__ambient"
        style={{
          background: `radial-gradient(closest-side at 50% 42%, ${panel.accent}28, transparent 72%)`,
        }}
      />
      <div className="device-scene-3d__stage">
        <div className="device-scene-3d__phone">
          <DeviceMockup
            device={iPhone16Pro}
            color="Natural Titanium"
            basePath={MOCKIFY_BASE_PATH}
            showStatusBar={false}
            width={width}
            className="device-mockup-frame device-mockup-frame--depth"
          >
            <div className="relative h-full w-full" role="img" aria-label={panel.screenAlt}>
              {inView &&
                panels.map((p, i) => (
                  <div
                    key={p.key}
                    className={clsx(
                      "absolute inset-0 transition-opacity duration-500",
                      i === activeIndex ? "opacity-100" : "pointer-events-none opacity-0"
                    )}
                  >
                    <AppScreen variant={appScreenForJourney(p.key)} />
                  </div>
                ))}
            </div>
          </DeviceMockup>
        </div>
      </div>
      <div aria-hidden className="device-scene-3d__shadow" />
    </div>
  );
}
