"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import Lenis from "lenis";

export default function SmoothScroll() {
  const pathname = usePathname();
  const lenisRef = useRef<Lenis | null>(null);

  useEffect(() => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) return;

    const lenis = new Lenis({
      duration: 1.05,
      easing: (t) => 1 - Math.pow(1 - t, 4),
      smoothWheel: true,
      touchMultiplier: 1.2,
      syncTouch: true,
      autoResize: true,
    });
    lenisRef.current = lenis;

    let raf = 0;
    const loop = (time: number) => {
      lenis.raf(time);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);

    const resize = () => lenis.resize();

    window.addEventListener("resize", resize);
    window.addEventListener("load", resize);

    const main = document.getElementById("main-content");
    const ro = new ResizeObserver(() => resize());
    ro.observe(document.documentElement);
    if (main) ro.observe(main);

    const t1 = window.setTimeout(resize, 150);
    const t2 = window.setTimeout(resize, 600);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
      window.removeEventListener("load", resize);
      clearTimeout(t1);
      clearTimeout(t2);
      ro.disconnect();
      lenis.destroy();
      lenisRef.current = null;
    };
  }, []);

  useEffect(() => {
    const lenis = lenisRef.current;
    if (!lenis) return;

    lenis.resize();
    lenis.scrollTo(0, { immediate: true, force: true });
    requestAnimationFrame(() => lenis.resize());
  }, [pathname]);

  return null;
}
