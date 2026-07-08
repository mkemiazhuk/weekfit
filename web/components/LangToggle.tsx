"use client";

import { useI18n } from "@/lib/i18n";
import clsx from "clsx";

const LABELS: Record<"en" | "ru", string> = {
  en: "English",
  ru: "Русский",
};

export default function LangToggle() {
  const { lang, setLang } = useI18n();
  return (
    <div
      role="group"
      aria-label={lang === "ru" ? "Язык" : "Language"}
      className="inline-flex rounded-full border border-white/10 bg-white/[0.03] p-0.5"
    >
      {(["en", "ru"] as const).map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => setLang(l)}
          className={clsx(
            "rounded-full px-2.5 py-1 text-[12px] font-semibold uppercase transition-all duration-300",
            lang === l
              ? "scale-100 bg-white text-black shadow-sm"
              : "scale-95 text-white/55 hover:scale-100 hover:text-white"
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
