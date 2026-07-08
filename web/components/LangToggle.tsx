"use client";

import { useI18n } from "@/lib/i18n";
import clsx from "clsx";

export default function LangToggle() {
  const { lang, setLang } = useI18n();
  return (
    <div className="inline-flex rounded-full border border-white/10 bg-white/[0.03] p-0.5">
      {(["en", "ru"] as const).map((l) => (
        <button
          key={l}
          onClick={() => setLang(l)}
          className={clsx(
            "rounded-full px-2.5 py-1 text-[12px] font-semibold uppercase transition-colors",
            lang === l ? "bg-white text-black" : "text-white/55 hover:text-white"
          )}
          aria-pressed={lang === l}
        >
          {l}
        </button>
      ))}
    </div>
  );
}
