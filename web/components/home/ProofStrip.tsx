"use client";

import { motion, useReducedMotion } from "framer-motion";
import { useI18n } from "@/lib/i18n";
import { easeCalm } from "@/lib/motion";

export default function ProofStrip() {
  const { t } = useI18n();
  const reduce = useReducedMotion();

  return (
    <section
      aria-label={t.proof.ariaLabel}
      className="relative z-[1] border-y border-white/[0.06] bg-white/[0.015]"
    >
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-gradient-to-r from-transparent via-white/[0.02] to-transparent"
      />
      <div className="mx-auto max-w-6xl section-x py-7 md:py-8">
        <ul className="grid grid-cols-2 gap-x-4 gap-y-3.5 md:grid-cols-4 md:gap-0">
          {t.proof.items.map((item, i) => (
            <motion.li
              key={item}
              initial={reduce ? {} : { opacity: 0, y: 8 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-10% 0px" }}
              transition={{ duration: 0.6, ease: easeCalm, delay: i * 0.06 }}
              className="proof-strip flex items-center gap-2.5 border-white/[0.06] md:justify-center md:border-l md:px-6 md:first:border-l-0"
            >
              <span
                aria-hidden
                className="proof-dot h-1 w-1 shrink-0 rounded-full bg-brand"
              />
              {item}
            </motion.li>
          ))}
        </ul>
      </div>
    </section>
  );
}
