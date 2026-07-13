"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";

const MOBILE_SCROLL_MQ = "(max-width: 767px)";

function prefersNativeScroll() {
  return window.matchMedia(MOBILE_SCROLL_MQ).matches;
}

type LenisInstance = {
  raf: (time: number) => void;
  resize: () => void;
  scrollTo: (
    target: number,
    opts?: { immediate?: boolean; duration?: number; force?: boolean }
  ) => void;
  destroy: () => void;
};

type LenisConstructor = new (opts: {
  duration: number;
  easing: (t: number) => number;
  smoothWheel: boolean;
  autoResize: boolean;
}) => LenisInstance;

export default function SmoothScroll() {
  const pathname = usePathname();
  const lenisRef = useRef<LenisInstance | null>(null);
  const rafRef = useRef(0);
  const cleanupRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    const reduceMq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const mobileMq = window.matchMedia(MOBILE_SCROLL_MQ);

    const onScrollTop = (e: Event) => {
      const immediate = (e as CustomEvent<{ immediate?: boolean }>).detail?.immediate;
      const lenis = lenisRef.current;
      if (lenis) {
        lenis.scrollTo(0, { immediate: !!immediate, duration: immediate ? 0 : 1.05 });
        return;
      }
      window.scrollTo({ top: 0, behavior: immediate ? "auto" : "smooth" });
    };

    window.addEventListener("weekfit:scroll-top", onScrollTop);

    const destroyLenis = () => {
      cancelAnimationFrame(rafRef.current);
      cleanupRef.current?.();
      cleanupRef.current = null;
      lenisRef.current?.destroy();
      lenisRef.current = null;
    };

    const initLenis = async () => {
      if (lenisRef.current) return;

      const { default: Lenis } = (await import("lenis")) as {
        default: LenisConstructor;
      };

      const lenis = new Lenis({
        duration: 1.05,
        easing: (t) => 1 - Math.pow(1 - t, 4),
        smoothWheel: true,
        autoResize: true,
      });
      lenisRef.current = lenis;

      const loop = (time: number) => {
        lenis.raf(time);
        rafRef.current = requestAnimationFrame(loop);
      };
      rafRef.current = requestAnimationFrame(loop);

      const resize = () => lenis.resize();
      window.addEventListener("resize", resize);
      window.addEventListener("load", resize);

      const main = document.getElementById("main-content");
      const ro = new ResizeObserver(() => resize());
      ro.observe(document.documentElement);
      if (main) ro.observe(main);

      const t1 = window.setTimeout(resize, 150);
      const t2 = window.setTimeout(resize, 600);

      cleanupRef.current = () => {
        window.removeEventListener("resize", resize);
        window.removeEventListener("load", resize);
        clearTimeout(t1);
        clearTimeout(t2);
        ro.disconnect();
      };
    };

    const sync = () => {
      if (reduceMq.matches || prefersNativeScroll()) {
        destroyLenis();
        return;
      }
      void initLenis();
    };

    sync();
    mobileMq.addEventListener("change", sync);
    reduceMq.addEventListener("change", sync);

    return () => {
      mobileMq.removeEventListener("change", sync);
      reduceMq.removeEventListener("change", sync);
      destroyLenis();
      window.removeEventListener("weekfit:scroll-top", onScrollTop);
    };
  }, []);

  useEffect(() => {
    const lenis = lenisRef.current;
    if (!lenis) {
      window.scrollTo({ top: 0, left: 0, behavior: "auto" });
      return;
    }

    lenis.resize();
    lenis.scrollTo(0, { immediate: true, force: true });
    requestAnimationFrame(() => lenis.resize());
  }, [pathname]);

  return null;
}
