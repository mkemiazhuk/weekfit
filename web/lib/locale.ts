import { SITE } from "./site";

export type Locale = "en" | "ru";
export const LOCALES: Locale[] = ["en", "ru"];
export const DEFAULT_LOCALE: Locale = "en";

export function localeFromPathname(pathname: string): Locale {
  return pathname === "/ru" || pathname.startsWith("/ru/") ? "ru" : "en";
}

/** Remove /ru prefix; returns paths like `/`, `/download/`. */
export function stripLocalePath(pathname: string): string {
  let p = pathname.split("#")[0] || "/";
  if (p === "/ru") return "/";
  if (p.startsWith("/ru/")) p = p.slice(3) || "/";
  if (p !== "/" && !p.endsWith("/")) p += "/";
  return p;
}

/** Locale-aware site path (trailing slash, hash preserved). */
export function localizedPath(rawPath: string, locale: Locale): string {
  const [pathPart, hash] = rawPath.split("#");
  const neutral = stripLocalePath(pathPart || "/");
  let result =
    locale === "ru"
      ? neutral === "/"
        ? "/ru/"
        : `/ru${neutral}`
      : neutral;
  if (hash) result += `#${hash}`;
  return result;
}

export function absLocalized(rawPath: string, locale: Locale): string {
  const [pathPart, hash] = rawPath.split("#");
  const lp = localizedPath(pathPart || "/", locale).replace(/\/$/, "") || "/";
  const base =
    lp === "/"
      ? `${SITE.url}/`
      : lp === "/ru"
        ? `${SITE.url}/ru/`
        : `${SITE.url}${lp.startsWith("/") ? lp : `/${lp}`}/`;
  return hash ? `${base.replace(/\/$/, "")}#${hash}` : base;
}

export function hreflangAlternates(rawPath: string): Record<string, string> {
  return {
    en: absLocalized(rawPath, "en"),
    ru: absLocalized(rawPath, "ru"),
    "x-default": absLocalized(rawPath, "en"),
  };
}
