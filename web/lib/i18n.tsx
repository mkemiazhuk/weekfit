"use client";

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
} from "react";
import { usePathname } from "next/navigation";
import { dictionaries, type Dict, type Lang } from "./dictionaries";
import { localeFromPathname, localizedPath, stripLocalePath } from "./locale";
import { useForcedLocale } from "./locale-context";

export type { Dict, Lang };

interface I18nValue {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: Dict;
  localePath: (path: string) => string;
}

const I18nContext = createContext<I18nValue | null>(null);

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const forcedLocale = useForcedLocale();
  const lang = forcedLocale ?? localeFromPathname(pathname ?? "/");

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const setLang = useCallback(
    (next: Lang) => {
      const neutral = stripLocalePath(pathname ?? "/");
      const target = localizedPath(neutral, next);
      document.documentElement.lang = next;
      try {
        localStorage.setItem("weekfit_lang", next);
      } catch {}
      window.location.assign(target);
    },
    [pathname]
  );

  const localePath = useCallback(
    (path: string) => localizedPath(path, lang),
    [lang]
  );

  const value = useMemo<I18nValue>(
    () => ({ lang, setLang, t: dictionaries[lang], localePath }),
    [lang, setLang, localePath]
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nValue {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error("useI18n must be used within I18nProvider");
  return ctx;
}
