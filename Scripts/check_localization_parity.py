#!/usr/bin/env python3
"""Fail when Localizable.xcstrings keys are missing EN or RU localizations."""

from __future__ import annotations

import json
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "WeekFit" / "Localizable.xcstrings"
IGNORED_PREFIXES = ("common.unit.",)


def main() -> int:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.get("strings", {})

    missing: list[str] = []
    for key, entry in sorted(strings.items()):
        if not key or key.startswith("%") or key in {".", "|", "0", "Week%@"}:
            continue
        if any(key.startswith(prefix) for prefix in IGNORED_PREFIXES):
            continue

        localizations = entry.get("localizations", {})
        en = localizations.get("en", {}).get("stringUnit", {}).get("value")
        ru = localizations.get("ru", {}).get("stringUnit", {}).get("value")

        if not en or not ru:
            missing.append(key)

    if missing:
        print(f"Localization parity check failed: {len(missing)} key(s) missing EN or RU")
        for key in missing[:50]:
            print(f"  - {key}")
        if len(missing) > 50:
            print(f"  ... and {len(missing) - 50} more")
        return 1

    print(f"Localization parity check passed ({len(strings)} keys)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
