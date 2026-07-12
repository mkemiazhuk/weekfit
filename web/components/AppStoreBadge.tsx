"use client";

import { useI18n } from "@/lib/i18n";

export default function AppStoreBadge({
  soon,
  footnote,
  align = "start",
}: {
  soon?: string;
  footnote?: string;
  align?: "start" | "center";
}) {
  const { t } = useI18n();

  return (
    <div
      className={`inline-flex flex-col gap-2 ${
        align === "center" ? "items-center" : "items-center sm:items-start"
      }`}
    >
      <span
        role="img"
        tabIndex={-1}
        aria-label={soon ? `${t.cta.appStoreLine2}. ${soon}` : t.cta.appStoreLine2}
        className="inline-flex cursor-default items-center gap-3 rounded-button border border-white/10 bg-black/40 px-5 py-3 opacity-60"
      >
        <svg viewBox="0 0 24 24" className="h-7 w-7 fill-white/80" aria-hidden>
          <path d="M16.365 1.43c0 1.14-.42 2.2-1.12 2.98-.75.85-1.98 1.5-3.02 1.42-.13-1.1.44-2.28 1.1-3.02.74-.83 2.03-1.44 3.04-1.38zM20.9 17.1c-.55 1.28-.82 1.85-1.53 2.99-.99 1.59-2.38 3.57-4.1 3.58-1.53.02-1.92-.99-4-.98-2.07.01-2.5.99-4.03.98-1.72-.01-3.04-1.79-4.03-3.38-2.77-4.45-3.06-9.67-1.35-12.45 1.21-1.97 3.13-3.12 4.93-3.12 1.84 0 2.99 1 4.51 1 1.47 0 2.37-1 4.5-1 1.61 0 3.32.88 4.53 2.39-3.98 2.18-3.33 7.85.57 9.99z" />
        </svg>
        <span className="text-left leading-tight">
          <span className="block text-[10px] uppercase tracking-wide text-white/45">
            {t.cta.appStoreLine1}
          </span>
          <span className="block text-[18px] font-semibold text-white/75">
            {t.cta.appStoreLine2}
          </span>
        </span>
      </span>
      {soon && <span className="caption">{soon}</span>}
      {footnote && <span className="max-w-[28ch] text-[12px] leading-relaxed text-white/35">{footnote}</span>}
    </div>
  );
}
