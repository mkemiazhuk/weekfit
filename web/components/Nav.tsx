"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import clsx from "clsx";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import Wordmark from "./Wordmark";
import LangToggle from "./LangToggle";
import Button from "./Button";
import { SITE } from "@/lib/site";
import { useI18n } from "@/lib/i18n";
import { easeCalm } from "@/lib/motion";

const FOCUSABLE =
  'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])';

export default function Nav() {
  const { t, localePath } = useI18n();
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const reduce = useReducedMotion();
  const menuButtonRef = useRef<HTMLButtonElement>(null);
  const menuPanelRef = useRef<HTMLDivElement>(null);

  const closeMenu = useCallback(() => setOpen(false), []);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    if (!open) return;

    const prevOverflow = document.body.style.overflow;
    const prevTouchAction = document.body.style.touchAction;
    document.body.style.overflow = "hidden";
    document.body.style.touchAction = "none";

    const inertTargets = [
      document.getElementById("main-content"),
      document.querySelector("footer"),
      ...Array.from(document.querySelectorAll<HTMLElement>(".scroll-to-top")),
    ].filter(Boolean) as HTMLElement[];
    inertTargets.forEach((el) => el.setAttribute("inert", ""));

    const panel = menuPanelRef.current;
    const focusables = panel
      ? Array.from(panel.querySelectorAll<HTMLElement>(FOCUSABLE))
      : [];
    const first = focusables[0];
    const last = focusables[focusables.length - 1];

    requestAnimationFrame(() => first?.focus());

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        closeMenu();
        return;
      }

      if (e.key !== "Tab" || !panel) return;

      if (focusables.length === 0) {
        e.preventDefault();
        return;
      }

      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault();
          last?.focus();
        }
      } else if (document.activeElement === last) {
        e.preventDefault();
        first?.focus();
      }
    };

    window.addEventListener("keydown", onKeyDown);

    return () => {
      document.body.style.overflow = prevOverflow;
      document.body.style.touchAction = prevTouchAction;
      inertTargets.forEach((el) => el.removeAttribute("inert"));
      window.removeEventListener("keydown", onKeyDown);
      requestAnimationFrame(() => menuButtonRef.current?.focus());
    };
  }, [open, closeMenu]);

  const desktopLinks = [
    { href: localePath("/#experience"), label: t.nav.features },
    { href: localePath("/experience"), label: t.nav.simulator },
    { href: localePath("/blog"), label: t.nav.blog },
    { href: localePath("/privacy"), label: t.nav.privacy },
    { href: localePath("/support"), label: t.nav.support },
  ];

  const mobileMenuLinks = [
    { href: localePath("/"), label: t.nav.home },
    { href: localePath("/#experience"), label: t.nav.features },
    { href: localePath("/privacy"), label: t.nav.privacy },
    { href: localePath("/support"), label: t.nav.support },
  ];

  return (
    <>
    <header
      className={clsx(
        "site-header fixed inset-x-0 top-0 z-50 transition-[border-color,background-color,box-shadow] duration-[var(--duration-surface)] ease-[cubic-bezier(0.22,1,0.36,1)]",
        scrolled || open
          ? "border-b border-white/[0.08] bg-canvas/72 shadow-[var(--shadow-nav)] backdrop-blur-2xl backdrop-saturate-150"
          : "border-b border-transparent"
      )}
    >
      <nav
        aria-label="Primary"
        className="site-header__bar mx-auto grid h-[3.5rem] max-w-6xl grid-cols-[minmax(0,1fr)_auto] items-center gap-x-2 section-x md:flex md:h-16 md:justify-between md:gap-3 lg:h-[4.5rem]"
      >
        <div className="min-w-0 pr-1 md:hidden">
          <Wordmark size="navMobile" className="wordmark-lockup--nav-mobile" />
        </div>
        <div className="hidden shrink-0 md:block">
          <Wordmark size="nav" className="wordmark-lockup--nav-desktop" />
        </div>

        <div className="hidden items-center gap-8 md:flex lg:gap-10">
          {desktopLinks.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="nav-link transition-colors duration-300 hover:text-white max-lg:text-[0.8125rem] lg:hover:text-white/90"
            >
              {l.label}
            </a>
          ))}
        </div>

        <div className="flex shrink-0 items-center justify-end md:gap-3">
          <div className="hidden md:block">
            <LangToggle />
          </div>

          <div className="hidden md:block">
            <Button href={SITE.appInstallUrl} external size="nav" className="btn-nav-cta">
              {t.cta.testflight}
            </Button>
          </div>

          <button
            ref={menuButtonRef}
            type="button"
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
            aria-controls="mobile-menu"
            aria-haspopup="dialog"
            aria-label={open ? t.nav.closeMenu : t.nav.menu}
            className="nav-menu-btn relative grid h-11 w-11 shrink-0 touch-manipulation place-items-center rounded-full text-white transition-[background,transform,color] duration-300 active:scale-[0.94] md:hidden"
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
    </header>

    <AnimatePresence>
      {open && (
        <>
          <motion.button
            type="button"
            aria-label={t.nav.closeMenu}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: reduce ? 0.12 : 0.22, ease: easeCalm }}
            className="mobile-menu-scrim fixed inset-0 z-[45] touch-manipulation border-0 md:hidden"
            onClick={closeMenu}
          />
          <motion.div
            id="mobile-menu"
            ref={menuPanelRef}
            role="dialog"
            aria-modal="true"
            aria-label={t.nav.menu}
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, y: 8 }}
            transition={{ duration: reduce ? 0.12 : 0.28, ease: easeCalm }}
            className="mobile-menu-panel fixed inset-x-0 bottom-0 z-[48] flex flex-col overflow-y-auto overscroll-contain md:hidden"
          >
            <nav aria-label="Mobile" className="mobile-menu-panel__inner mx-auto flex w-full max-w-6xl flex-1 flex-col section-x">
              <ul className="mobile-menu-links flex flex-col divide-y divide-white/[0.06] border-y border-white/[0.06]">
                {mobileMenuLinks.map((l) => (
                  <li key={l.href}>
                    <a
                      href={l.href}
                      onClick={closeMenu}
                      className="mobile-menu-link flex min-h-11 items-center justify-between py-3 text-[17px] font-medium text-white/82 transition-colors hover:text-white active:text-white"
                    >
                      {l.label}
                      <span aria-hidden className="text-white/30">
                        →
                      </span>
                    </a>
                  </li>
                ))}
              </ul>

              <div className="mobile-menu-lang mt-6">
                <p className="caption mb-2.5 text-white/38">
                  {t.nav.menu === "Menu" ? "Language" : "Язык"}
                </p>
                <LangToggle variant="menu" />
              </div>

              <Button
                href={SITE.appInstallUrl}
                external
                size="md"
                className="mobile-menu-cta mt-8 w-full"
                onClick={closeMenu}
              >
                {t.cta.testflight}
              </Button>
            </nav>
          </motion.div>
        </>
      )}
    </AnimatePresence>
    </>
  );
}
