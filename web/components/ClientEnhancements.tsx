"use client";

import dynamic from "next/dynamic";
import { useEffect, useState } from "react";

const SmoothScroll = dynamic(() => import("./SmoothScroll"));
const AtmosphereBackground = dynamic(() => import("./AtmosphereBackground"));
const ScrollProgress = dynamic(() => import("./ScrollProgress"));
const ScrollToTop = dynamic(() => import("./ScrollToTop"));

export default function ClientEnhancements() {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const enable = () => setReady(true);

    if (typeof window.requestIdleCallback === "function") {
      const id = window.requestIdleCallback(enable, { timeout: 1800 });
      return () => window.cancelIdleCallback(id);
    }

    const timer = window.setTimeout(enable, 1);
    return () => window.clearTimeout(timer);
  }, []);

  if (!ready) return null;

  return (
    <>
      <ScrollProgress />
      <ScrollToTop />
      <SmoothScroll />
      <AtmosphereBackground />
    </>
  );
}
