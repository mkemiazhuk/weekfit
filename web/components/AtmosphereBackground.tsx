"use client";

import { useEffect, useRef } from "react";
import { atmosphereAt } from "@/lib/tokens";

// Fixed full-viewport background whose color evolves morning -> night as the
// visitor scrolls the whole page. Also publishes a global `--night` factor
// (0 vivid day -> 1 calm night) that other components can read.
export default function AtmosphereBackground() {
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = rootRef.current;
    if (!el) return;
    const docEl = document.documentElement;

    let ticking = false;
    const update = () => {
      ticking = false;
      const max = document.body.scrollHeight - window.innerHeight;
      const p = max > 0 ? window.scrollY / max : 0;
      const a = atmosphereAt(p);

      el.style.setProperty("--b1", a.base[0]);
      el.style.setProperty("--b2", a.base[1]);
      el.style.setProperty("--b3", a.base[2]);
      el.style.setProperty(
        "--g1",
        `${Math.round(a.glow1[0])}, ${Math.round(a.glow1[1])}, ${Math.round(
          a.glow1[2]
        )}`
      );
      el.style.setProperty("--g1a", `${a.glow1Alpha}`);
      el.style.setProperty(
        "--g2",
        `${Math.round(a.glow2[0])}, ${Math.round(a.glow2[1])}, ${Math.round(
          a.glow2[2]
        )}`
      );
      el.style.setProperty("--g2a", `${a.glow2Alpha}`);
      docEl.style.setProperty("--night", a.night.toFixed(3));
    };

    const onScroll = () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    };

    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, []);

  return (
    <div
      ref={rootRef}
      aria-hidden
      className="atmosphere pointer-events-none fixed inset-0 -z-10 overflow-hidden"
      style={
        {
          "--b1": "#080f1a",
          "--b2": "#05070d",
          "--b3": "#030305",
          "--g1": "107, 184, 224",
          "--g1a": "0.16",
          "--g2": "140, 209, 156",
          "--g2a": "0.1",
        } as React.CSSProperties
      }
    >
      <div className="atm-base" />
      <div className="atm-volumetric" />
      <div className="atm-glow atm-glow-1" />
      <div className="atm-glow atm-glow-2" />
      <div className="atm-stars" />
      <div className="atm-grain" />
    </div>
  );
}
