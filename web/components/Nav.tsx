"use client";

import { useEffect, useState } from "react";
import clsx from "clsx";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import Wordmark from "./Wordmark";
import LangToggle from "./LangToggle";
import { useI18n } from "@/lib/i18n";

export default function Nav() {
  const { t } = useI18n();
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const reduce = useReducedMotion();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  // Lock scroll and close on Escape while the mobile menu is open.
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const links = [
    { href: "/", label: t.nav.home },
    { href: "/#experience", label: t.nav.features },
    { href: "/privacy", label: t.nav.privacy },
    { href: "/support", label: t.nav.support },
  ];

  return (
    <header
      className={clsx(
        "fixed inset-x-0 top-0 z-50 transition-all duration-500",
        scrolled || open
          ? "border-b border-white/[0.07] bg-canvas/60 backdrop-blur-xl"
          : "border-b border-transparent"
      )}
    >
      <nav
        aria-label="Primary"
        className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6"
      >
        <Wordmark />

        <div className="hidden items-center gap-8 md:flex">
          {links.slice(1).map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="text-[14px] text-white/60 transition-colors hover:text-white"
            >
              {l.label}
            </a>
          ))}
        </div>

        <div className="flex items-center gap-3">
          <LangToggle />
          <a
            href="/download"
            className="hidden rounded-full bg-white px-4 py-2 text-[13px] font-semibold text-black transition-transform hover:-translate-y-0.5 sm:inline-block"
          >
            {t.cta.notify}
          </a>

          {/* Mobile menu trigger */}
          <button
            type="button"
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
            aria-controls="mobile-menu"
            aria-label={open ? t.nav.closeMenu : t.nav.menu}
            className="relative -mr-1 grid h-10 w-10 place-items-center rounded-full text-white transition-colors hover:bg-white/[0.06] md:hidden"
          >
            <span className="relative block h-3.5 w-5" aria-hidden>
              <span
                className={clsx(
                  "absolute left-0 h-[1.5px] w-5 rounded-full bg-current transition-all duration-300",
                  open ? "top-1/2 -translate-y-1/2 rotate-45" : "top-0"
                )}
              />
              <span
                className={clsx(
                  "absolute left-0 top-1/2 h-[1.5px] w-5 -translate-y-1/2 rounded-full bg-current transition-opacity duration-200",
                  open ? "opacity-0" : "opacity-100"
                )}
              />
              <span
                className={clsx(
                  "absolute left-0 h-[1.5px] w-5 rounded-full bg-current transition-all duration-300",
                  open ? "top-1/2 -translate-y-1/2 -rotate-45" : "bottom-0"
                )}
              />
            </span>
          </button>
        </div>
      </nav>

      <AnimatePresence>
        {open && (
          <motion.div
            id="mobile-menu"
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, y: -8 }}
            transition={{ duration: reduce ? 0.15 : 0.28, ease: [0.22, 1, 0.36, 1] }}
            className="md:hidden"
          >
            <nav
              aria-label="Mobile"
              className="mx-auto max-w-6xl px-6 pb-6 pt-2"
            >
              <ul className="flex flex-col divide-y divide-white/[0.06] border-y border-white/[0.06]">
                {links.map((l) => (
                  <li key={l.href}>
                    <a
                      href={l.href}
                      onClick={() => setOpen(false)}
                      className="flex items-center justify-between py-4 text-[17px] font-medium text-white/80 transition-colors hover:text-white"
                    >
                      {l.label}
                      <span aria-hidden className="text-white/30">
                        →
                      </span>
                    </a>
                  </li>
                ))}
              </ul>
              <a
                href="/download"
                onClick={() => setOpen(false)}
                className="mt-6 block rounded-full bg-white px-5 py-3.5 text-center text-[15px] font-semibold text-black"
              >
                {t.cta.notify}
              </a>
            </nav>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  );
}
