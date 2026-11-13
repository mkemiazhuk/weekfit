"use client";

import { useI18n } from "@/lib/i18n";
import clsx from "clsx";

const LABELS: Record<"en" | "ru", string> = {
  en: "English",
  ru: "Русский",
};

export default function LangToggle({ variant = "default" }: { variant?: "default" | "menu" }) {
  const { lang, setLang } = useI18n();
  const isMenu = variant === "menu";

  return (
    <div
      role="group"
      aria-label={lang === "ru" ? "Язык" : "Language"}
      className={clsx(
        "lang-toggle inline-flex shrink-0 rounded-full border p-0.5",
        isMenu
          ? "lang-toggle--menu w-full border-black/[0.08] bg-black/[0.03]"
          : "border-black/10 bg-black/[0.03]"
      )}
    >
      {(["en", "ru"] as const).map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => setLang(l)}
          className={clsx(
            "lang-toggle-btn rounded-full font-semibold uppercase transition-all duration-300",
            isMenu
              ? "min-h-11 flex-1 px-3 py-2 text-[11px] tracking-[0.06em]"
              : "px-2.5 py-1 text-[12px]",
            lang === l
              ? isMenu
                ? "bg-white text-ink shadow-none ring-1 ring-black/[0.06]"
                : "scale-100 bg-white text-ink shadow-sm"
              : isMenu
                ? "text-ink/45 hover:text-ink/72"
                : "scale-95 text-ink/55 hover:scale-100 hover:text-ink"
          )}
          aria-pressed={lang === l}
          aria-label={LABELS[l]}
        >
          {l}
        </button>
      ))}
    </div>
  );
}
