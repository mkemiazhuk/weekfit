"use client";

import { useI18n } from "@/lib/i18n";

export default function ProofStrip() {
  const { t } = useI18n();

  return (
    <section aria-label={t.proof.ariaLabel} className="relative z-[1] border-y border-white/[0.06] bg-white/[0.02]">
      <div className="mx-auto max-w-6xl section-x py-5">
        <ul className="flex flex-wrap items-center justify-center gap-x-6 gap-y-2 md:justify-start md:gap-x-10">
          {t.proof.items.map((item) => (
            <li key={item} className="flex items-center gap-2 text-[13px] text-white/50">
              <span
                aria-hidden
                className="h-1 w-1 rounded-full bg-brand"
                style={{ boxShadow: "0 0 6px rgba(102,188,135,0.6)" }}
              />
              {item}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
