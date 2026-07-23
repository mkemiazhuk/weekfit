#!/usr/bin/env python3
"""Fail when RU strings contain disallowed English or EN strings contain Cyrillic."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "WeekFit" / "Localizable.xcstrings"
IGNORED_PREFIXES = ("common.unit.",)
SKIP_KEYS = {"", ".", "|", "0", "Week%@"}
# Native language names intentionally use the language's own script in both locales.
SKIP_CYRILLIC_IN_EN_KEYS = {
    "onboarding.v8.language.option.russian",
}

# Latin tokens allowed inside Russian copy (units, brands, acronyms, filenames).
ALLOWED_LATIN = {
    "am", "pm", "hr", "hrs", "min", "mins", "kcal", "cal", "hrv", "bpm",
    "gps", "hiit", "vo2", "tabata", "core", "ok", "weekfit", "healthkit",
    "apple", "health", "watch", "iphone", "ios", "mac", "pro", "max",
    "strava", "garmin", "fitbit", "whoop", "oura", "gmail", "icloud",
    "http", "https", "www", "com", "api", "id", "uuid", "json", "xml",
    "mg", "kg", "g", "ml", "l", "km", "mi", "ft", "cm", "mm",
    "mon", "tue", "wed", "thu", "fri", "sat", "sun",
    "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
    "email", "sms", "push", "wifi", "bluetooth", "nfc", "beta", "alpha", "v1", "v2", "v3",
    "rem", "rhr", "bmr", "tdee", "faq", "nil", "fit", "app", "store",
    # Product surface / brand nouns kept in Latin inside RU copy
    "coach", "today", "meals", "plan", "english", "russian",
    # Third-party source labels
    "usda", "open", "food", "facts",
}

CYRILLIC_RE = re.compile(r"[А-Яа-яЁё]")
LATIN_WORD_RE = re.compile(r"[a-zA-Z]{3,}")
PLACEHOLDER_RE = re.compile(r"%[\d\$]*[lldfs@]*")


def strip_placeholders(text: str) -> str:
    cleaned = PLACEHOLDER_RE.sub(" ", text)
    return re.sub(r"\{[^}]+\}", " ", cleaned)


def disallowed_latin_words(text: str) -> list[str]:
    cleaned = strip_placeholders(text)
    words = LATIN_WORD_RE.findall(cleaned.lower())
    return sorted({word for word in words if word not in ALLOWED_LATIN})


def main() -> int:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.get("strings", {})

    ru_violations: list[str] = []
    en_violations: list[str] = []

    for key, entry in sorted(strings.items()):
        if not key or key.startswith("%") or key in SKIP_KEYS:
            continue
        if any(key.startswith(prefix) for prefix in IGNORED_PREFIXES):
            continue

        localizations = entry.get("localizations", {})
        en = localizations.get("en", {}).get("stringUnit", {}).get("value", "")
        ru = localizations.get("ru", {}).get("stringUnit", {}).get("value", "")

        if ru:
            latin = disallowed_latin_words(ru)
            if latin:
                ru_violations.append(f"  - {key}: {', '.join(latin)}")

        if en and CYRILLIC_RE.search(en) and key not in SKIP_CYRILLIC_IN_EN_KEYS:
            en_violations.append(f"  - {key}")

    if ru_violations or en_violations:
        print("Localization language-mix check failed")
        if ru_violations:
            print(f"\nRU strings with disallowed English ({len(ru_violations)}):")
            for line in ru_violations[:50]:
                print(line)
            if len(ru_violations) > 50:
                print(f"  ... and {len(ru_violations) - 50} more")
        if en_violations:
            print(f"\nEN strings with Cyrillic ({len(en_violations)}):")
            for line in en_violations[:50]:
                print(line)
            if len(en_violations) > 50:
                print(f"  ... and {len(en_violations) - 50} more")
        return 1

    print(f"Localization language-mix check passed ({len(strings)} keys)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
