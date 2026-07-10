"use client";

import { useCallback, useEffect, useState } from "react";
import clsx from "clsx";
import { useI18n } from "@/lib/i18n";

const SHOW_AFTER_PX = 480;

export default function ScrollToTop() {
  const { t } = useI18n();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      setVisible(window.scrollY > SHOW_AFTER_PX);
    };

    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const scrollUp = useCallback(() => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.dispatchEvent(
      new CustomEvent("weekfit:scroll-top", { detail: { immediate: reduce } })
    );
  }, []);

  return (
    <button
      type="button"
      onClick={scrollUp}
      aria-label={t.a11y.scrollToTop}
      className={clsx(
        "scroll-to-top fixed right-4 z-50 flex h-11 w-11 items-center justify-center rounded-full md:right-6",
        visible ? "scroll-to-top--visible" : "scroll-to-top--hidden pointer-events-none"
      )}
    >
      <svg
        viewBox="0 0 24 24"
        width={18}
        height={18}
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden
      >
        <path d="M12 19V5M5 12l7-7 7 7" />
      </svg>
    </button>
  );
}
