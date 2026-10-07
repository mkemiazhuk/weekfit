#!/usr/bin/env python3
"""Translate Localizable.xcstrings / widget catalog EN → zh-Hans with resumable cache.

Usage:
  /tmp/weekfit-i18n/bin/python scripts/translate_xcstrings_zh_hans.py
  /tmp/weekfit-i18n/bin/python scripts/translate_xcstrings_zh_hans.py --apply
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "scripts" / ".zh_hans_translation_cache.json"
CATALOGS = [
    ROOT / "WeekFit" / "Localizable.xcstrings",
    ROOT / "WeekFitWidget" / "Localizable.xcstrings",
]

# Keep brand / codes / format-only strings as-is.
KEEP_AS_IS = re.compile(
    r"^("
    r"WeekFit|Coach|HRV|REM|BMI|BMI|kcal|BPM|ms|%|RPE|FAQ|OK|Pro|Premium"
    r"|%@|%lld|%lf|%d|%f"
    r"|[A-Za-z]"  # single Latin letters (C/F/P unit glyphs, etc.)
    r"|[0-9\s\-\–\—\:\.\,\/\+\*\(\)\[\]\|•·→←↑↓]+"
    r")$"
)


def load_cache() -> dict[str, str]:
    if CACHE.exists():
        return json.loads(CACHE.read_text(encoding="utf-8"))
    return {}


def save_cache(cache: dict[str, str]) -> None:
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def should_keep(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return True
    if KEEP_AS_IS.match(stripped):
        return True
    # Pure format templates with no letters
    if not re.search(r"[A-Za-z\u0400-\u04FF]", stripped):
        return True
    return False


def collect_english(catalogs: list[Path]) -> list[str]:
    values: set[str] = set()
    for path in catalogs:
        data = json.loads(path.read_text(encoding="utf-8"))
        for entry in data.get("strings", {}).values():
            en = (
                (entry.get("localizations") or {})
                .get("en", {})
                .get("stringUnit", {})
                .get("value")
            )
            if en:
                values.add(en)
    return sorted(values)


def translate_text(text: str) -> str:
    """Translate EN→zh-CN with placeholder protection. Tries several backends."""
    import os

    os.environ.setdefault("translators_default_region", "CN")
    import translators as ts

    placeholder_re = re.compile(
        r"%(?:\d+\$)?(?:ll)?[@dfFsSxX]|%lld|%lf|%[\d.]*[fg]|%@"
    )
    placeholders: list[str] = []

    def protect(match: re.Match[str]) -> str:
        placeholders.append(match.group(0))
        return f" XPH{len(placeholders) - 1}X "

    protected = placeholder_re.sub(protect, text)
    last_error: Exception | None = None
    zh: str | None = None
    for engine in ("sogou", "iciba"):
        try:
            candidate = ts.translate_text(
                protected,
                translator=engine,
                from_language="en",
                to_language="zh",
            )
            if not isinstance(candidate, str) or not candidate.strip():
                last_error = ValueError(f"empty translation from {engine}")
                continue
            # Reject opaque garbage tokens returned by some engines.
            if re.fullmatch(r"[a-z0-9]{8,}", candidate.strip()):
                last_error = ValueError(f"garbage token from {engine}: {candidate!r}")
                continue
            if not re.search(r"[\u4e00-\u9fff]", candidate) and re.search(r"[A-Za-z]", text):
                last_error = ValueError(f"no CJK from {engine}: {candidate!r}")
                continue
            zh = candidate
            break
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            continue
    if zh is None:
        raise last_error or ValueError(f"empty translation for {text!r}")
    for idx, token in enumerate(placeholders):
        zh = re.sub(rf"\s*XPH{idx}X\s*", token, zh)
    if re.search(r"XPH\d+X", zh):
        raise ValueError(f"placeholder leftover: {text!r} -> {zh!r}")
    if sorted(placeholder_re.findall(text)) != sorted(placeholder_re.findall(zh)):
        raise ValueError(f"placeholder mismatch: {text!r} -> {zh!r}")
    return zh


def translate_missing(values: list[str], cache: dict[str, str], limit: int | None) -> dict[str, str]:
    def _usable(v: str, cache: dict[str, str]) -> bool:
        zh = cache.get(v)
        if zh is None:
            return False
        if should_keep(v):
            return True
        if re.fullmatch(r"[a-z0-9]{8,}", (zh or "").strip() or ""):
            return False
        return bool(re.search(r"[\u4e00-\u9fff]", zh))

    pending = [v for v in values if not should_keep(v) and not _usable(v, cache)]
    if limit is not None:
        pending = pending[:limit]

    print(f"Translating {len(pending)} strings ({len(cache)} already cached)…", flush=True)
    for i, text in enumerate(pending, 1):
        try:
            cache[text] = translate_text(text)
        except Exception as exc:  # noqa: BLE001
            print(f"  ! failed [{i}/{len(pending)}]: {exc!r}", flush=True)
            time.sleep(0.8)
            continue
        if i % 25 == 0:
            save_cache(cache)
            print(f"  … {i}/{len(pending)}", flush=True)
            time.sleep(1.0)
        else:
            time.sleep(0.25)
    save_cache(cache)
    return cache


def apply_to_catalog(path: Path, cache: dict[str, str]) -> tuple[int, int]:
    data = json.loads(path.read_text(encoding="utf-8"))
    added = 0
    skipped = 0
    cjk_re = re.compile(r"[\u4e00-\u9fff]")
    for key, entry in data.get("strings", {}).items():
        locs = entry.setdefault("localizations", {})
        en = locs.get("en", {}).get("stringUnit", {}).get("value")
        if not en:
            skipped += 1
            continue
        existing = (locs.get("zh-Hans") or {}).get("stringUnit", {}).get("value")
        if should_keep(en):
            zh = en
        else:
            zh = cache.get(en)
            if not zh or (not cjk_re.search(zh) and not should_keep(zh)):
                skipped += 1
                continue
            # Never apply opaque garbage.
            if re.fullmatch(r"[a-z0-9]{8,}", zh.strip()):
                skipped += 1
                continue
        if existing and cjk_re.search(existing):
            skipped += 1
            continue
        locs["zh-Hans"] = {"stringUnit": {"state": "translated", "value": zh}}
        added += 1
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return added, skipped


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Write zh-Hans into catalogs")
    parser.add_argument("--limit", type=int, default=None, help="Max new translations this run")
    parser.add_argument("--translate-only", action="store_true")
    args = parser.parse_args()

    cache = load_cache()
    values = collect_english(CATALOGS)
    print(f"Unique EN values: {len(values)}")

    if not args.apply or args.translate_only or args.limit is not None:
        cache = translate_missing(values, cache, args.limit)

    if args.apply and not args.translate_only:
        # Fill keep-as-is into cache
        for v in values:
            if should_keep(v):
                cache.setdefault(v, v)
        save_cache(cache)
        for path in CATALOGS:
            added, skipped = apply_to_catalog(path, cache)
            print(f"{path.name}: wrote {added}, skipped {skipped}")
        missing = sum(1 for v in values if not should_keep(v) and v not in cache)
        print(f"Still missing translations: {missing}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
