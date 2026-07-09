"use client";

import { createContext, useContext } from "react";
import type { Lang } from "./dictionaries";

const LocaleConfigContext = createContext<Lang | null>(null);

export function LocaleConfigProvider({
  locale,
  children,
}: {
  locale: Lang;
  children: React.ReactNode;
}) {
  return (
    <LocaleConfigContext.Provider value={locale}>
      {children}
    </LocaleConfigContext.Provider>
  );
}

export function useForcedLocale(): Lang | null {
  return useContext(LocaleConfigContext);
}
