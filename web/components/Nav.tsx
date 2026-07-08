"use client";

import { useEffect, useState } from "react";
import clsx from "clsx";
import Wordmark from "./Wordmark";
import LangToggle from "./LangToggle";
import { useI18n } from "@/lib/i18n";

export default function Nav() {
  const { t } = useI18n();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={clsx(
        "fixed inset-x-0 top-0 z-50 transition-all duration-500",
        scrolled
          ? "border-b border-white/[0.07] bg-canvas/60 backdrop-blur-xl"
          : "border-b border-transparent"
      )}
    >
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <Wordmark />
        <div className="hidden items-center gap-8 md:flex">
          <a
            href="/#experience"
            className="text-[14px] text-white/60 transition-colors hover:text-white"
          >
            {t.nav.features}
          </a>
          <a
            href="/#pillars"
            className="text-[14px] text-white/60 transition-colors hover:text-white"
          >
            {t.nav.pillars}
          </a>
          <a
            href="/privacy"
            className="text-[14px] text-white/60 transition-colors hover:text-white"
          >
            {t.nav.privacy}
          </a>
        </div>
        <div className="flex items-center gap-3">
          <LangToggle />
          <a
            href="/download"
            className="hidden rounded-full bg-white px-4 py-2 text-[13px] font-semibold text-black transition-transform hover:-translate-y-0.5 sm:inline-block"
          >
            {t.nav.download}
          </a>
        </div>
      </nav>
    </header>
  );
}
