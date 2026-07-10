"use client";

import { useEffect, useState } from "react";
import clsx from "clsx";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import Wordmark from "./Wordmark";
import LangToggle from "./LangToggle";
import Button from "./Button";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeCalm } from "@/lib/motion";

export default function Nav() {
  const { t, localePath } = useI18n();
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const reduce = useReducedMotion();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

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
    { href: localePath("/"), label: t.nav.home },
    { href: localePath("/#experience"), label: t.nav.features },
    { href: localePath("/experience"), label: t.nav.simulator },
    { href: localePath("/blog"), label: t.nav.blog },
    { href: localePath("/privacy"), label: t.nav.privacy },
    { href: localePath("/support"), label: t.nav.support },
  ];

  return (
    <header
      className={clsx(
        "fixed inset-x-0 top-0 z-50 transition-all duration-500",
        scrolled || open
          ? "border-b border-white/[0.08] bg-canvas/72 shadow-[0_8px_32px_-12px_rgba(0,0,0,0.45)] backdrop-blur-2xl backdrop-saturate-150"
          : "border-b border-transparent"
      )}
    >
      <nav
        aria-label="Primary"
        className="mx-auto grid h-[3.75rem] max-w-6xl grid-cols-[minmax(0,1fr)_auto] items-center gap-x-3 section-x md:flex md:h-16 md:justify-between md:gap-3 lg:h-[4.5rem]"
      >
        <div className="min-w-0 md:hidden">
          <Wordmark size="navMobile" />
        </div>
        <div className="hidden min-w-0 md:block">
          <Wordmark size="nav" />
        </div>

        <div className="hidden items-center gap-8 md:flex lg:gap-10">
          {links.slice(1).map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="nav-link transition-colors duration-300 hover:text-white max-lg:text-[0.8125rem] lg:hover:text-white/90"
            >
              {l.label}
            </a>
          ))}
        </div>

        <div className="flex items-center justify-end gap-2.5 md:gap-3">
          <div className="max-md:[&_.lang-toggle]:p-0.5 max-md:[&_.lang-toggle-btn]:min-h-8 max-md:[&_.lang-toggle-btn]:min-w-8 max-md:[&_.lang-toggle-btn]:px-2 max-md:[&_.lang-toggle-btn]:py-1 max-md:[&_.lang-toggle-btn]:text-[11px]">
            <LangToggle />
          </div>

          <div className="md:hidden">
            <Button href={SITE.appInstallUrl} external size="xs" className="btn-nav-mobile-cta">
              {t.cta.testflight}
            </Button>
          </div>
          <div className="hidden md:block">
            <Button href={SITE.appInstallUrl} external size="nav" className="btn-nav-cta">
              {t.cta.testflight}
            </Button>
          </div>

          <button
            type="button"
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
            aria-controls="mobile-menu"
            aria-label={open ? t.nav.closeMenu : t.nav.menu}
            className="nav-menu-btn relative grid h-10 w-10 shrink-0 place-items-center rounded-full text-white transition-[background,transform,color] duration-300 active:scale-[0.94] md:hidden"
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
            transition={{ duration: reduce ? 0.15 : 0.28, ease: easeCalm }}
            className="md:hidden"
          >
            <nav aria-label="Mobile" className="mx-auto max-w-6xl section-x pb-6 pt-2">
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
              <Button
                href={SITE.appInstallUrl}
                external
                className="mt-6 w-full"
                onClick={() => setOpen(false)}
              >
                {t.cta.testflight}
              </Button>
            </nav>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  );
}
