#!/usr/bin/env python3
"""Re-runnable WeekFit localization completeness + placeholder audit.

Usage:
  python3 scripts/audit_localization.py
  python3 scripts/audit_localization.py --strict   # exit 1 on failures

Checks:
  - missing localizations for AppLanguage set
  - empty values
  - MT/corruption garbage patterns
  - placeholder token mismatches (%% and trailing % after digits treated as literals)
  - Cyrillic leaking into non-ru locales
Does NOT treat EN-identity as automatic failure (brand/loanwords need human context).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "WeekFit" / "Localizable.xcstrings"
WIDGET = ROOT / "WeekFitWidget" / "Localizable.xcstrings"
APP_LANGS = ["en", "ru", "zh-Hans", "fr", "pl", "es", "de", "ja", "it", "ko"]

GARBAGE = re.compile(
    r"TubePorn|PerTM|inTM|toTM|simpleTM|OpeningTM|ThisTM|LetTM|EnTM|⟦TM|TM0|"
    r"프레젠|プレゼンT0|PrettyT0|Pret0|vrt0|OTDR|ღ|開催概要|지원하다|^이용안내$|"
    r"디자인에 의해 개인|Elevation 이익|Synced from |지역 [1-5]",
    re.I,
)
CYRILLIC = re.compile(r"[А-Яа-яЁё]")


def extract_placeholders(text: str) -> list[str]:
    """Printf-style tokens; ignore %% and digit% literals like 30%."""
    s = re.sub(r"%%", "", text)
    s = re.sub(r"(?<=\d)%(?!\d|\$|@|[diouxXeEfFgGaAcspnhlqLzjt])", "", s)
    return re.findall(
        r"%(?:\d+\$)?[#0\-+]*(?:\d+)?(?:\.\d+)?(?:(?:h|hh|l|ll|q|L|z|t|j)*[diouxXeEfFgGaAcspn@]|@)",
        s,
    )


def value(entry: dict, lang: str) -> str | None:
    loc = (entry.get("localizations") or {}).get(lang) or {}
    unit = loc.get("stringUnit") or {}
    if "value" in unit:
        return unit.get("value")
    return None


def audit_catalog(path: Path, langs: list[str]) -> dict:
    data = json.loads(path.read_text())
    strings = data.get("strings") or {}
    missing: dict[str, list[str]] = defaultdict(list)
    empty: dict[str, list[str]] = defaultdict(list)
    garbage: list[tuple[str, str, str]] = []
    ph_mismatch: list[tuple[str, str, list[str], list[str]]] = []
    cyrillic_leak: list[tuple[str, str, str]] = []

    for key, entry in strings.items():
        if key == "":
            continue
        en = value(entry, "en")
        locs = entry.get("localizations") or {}
        for lang in langs:
            if lang == "en":
                continue
            if en is not None and lang not in locs:
                missing[lang].append(key)
                continue
            v = value(entry, lang)
            if v is None:
                continue
            if not str(v).strip():
                empty[lang].append(key)
            if GARBAGE.search(v):
                garbage.append((lang, key, v[:160]))
            if lang != "ru" and CYRILLIC.search(v) and (not en or not CYRILLIC.search(en)):
                cyrillic_leak.append((lang, key, v[:120]))
            if en:
                a, b = extract_placeholders(en), extract_placeholders(v)
                if Counter(a) != Counter(b):
                    ph_mismatch.append((lang, key, a, b))

    return {
        "path": str(path.relative_to(ROOT)),
        "keys": len(strings),
        "missing": {k: len(v) for k, v in sorted(missing.items())},
        "missing_keys": {k: v[:30] for k, v in sorted(missing.items())},
        "empty": {k: v for k, v in sorted(empty.items())},
        "garbage": garbage,
        "ph_mismatch_count": len(ph_mismatch),
        "ph_mismatch": [
            {"lang": a, "key": b, "en": c, "tr": d} for a, b, c, d in ph_mismatch[:80]
        ],
        "cyrillic_leak": cyrillic_leak,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true")
    parser.add_argument(
        "--out",
        type=Path,
        default=ROOT / ".tmp" / "i18n-audit" / "latest.json",
    )
    args = parser.parse_args()

    reports = [
        audit_catalog(MAIN, APP_LANGS),
        audit_catalog(WIDGET, APP_LANGS),
    ]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(reports, ensure_ascii=False, indent=2) + "\n")

    failures = 0
    for rep in reports:
        print(f"== {rep['path']} keys={rep['keys']}")
        print(" missing:", rep["missing"] or "{}")
        print(" empty:", {k: len(v) for k, v in rep["empty"].items()} or "{}")
        print(" garbage:", len(rep["garbage"]))
        print(" ph_mismatch:", rep["ph_mismatch_count"])
        print(" cyrillic_leak:", len(rep["cyrillic_leak"]))
        failures += sum(rep["missing"].values())
        failures += sum(len(v) for v in rep["empty"].values())
        failures += len(rep["garbage"])
        failures += rep["ph_mismatch_count"]
        failures += len(rep["cyrillic_leak"])
        for g in rep["garbage"][:10]:
            print("  GARBAGE", g)
        for c in rep["cyrillic_leak"][:10]:
            print("  CYR", c)
        for p in rep["ph_mismatch"][:15]:
            print("  PH", p["lang"], p["key"], p["en"], "->", p["tr"])

    print("wrote", args.out)
    if args.strict and failures:
        print(f"STRICT FAIL failures={failures}")
        return 1
    print(f"failures={failures}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
