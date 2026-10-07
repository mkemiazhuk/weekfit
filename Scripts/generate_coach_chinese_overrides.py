#!/usr/bin/env python3
"""Extract unique English Coach bilingual strings and generate CoachChineseOverridesTable.swift."""

from __future__ import annotations

import argparse
import json
import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COACH_DIR = ROOT / "WeekFit" / "Features" / "Nutrition" / "new" / "Coach"
OUT = ROOT / "WeekFit" / "Localization" / "CoachChineseOverridesTable.swift"
CACHE = ROOT / "scripts" / ".coach_zh_hans_cache.json"

BI_PATTERNS = [
    re.compile(r'\bbi\(\s*"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"\s*(?:,\s*chinese:\s*"((?:\\.|[^"\\])*)")?\s*\)'),
    re.compile(r'\.en\(\s*"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"\s*(?:,\s*chinese:\s*"((?:\\.|[^"\\])*)")?\s*\)'),
    re.compile(r'CoachBilingualText\(\s*english:\s*"((?:\\.|[^"\\])*)"\s*,\s*russian:\s*"((?:\\.|[^"\\])*)"'),
]

# printf + Swift string interpolations
PLACEHOLDER_RE = re.compile(
    r"%(?:\d+\$)?(?:ll)?[@dfFsSxX]|%lld|%lf|%[\d.]*[fg]|%@"
    r"|\\\([^)]*\)"
)


def unescape(s: str) -> str:
    """Decode common Swift escapes without mangling \\( interpolations)."""
    out: list[str] = []
    i = 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            nxt = s[i + 1]
            if nxt == "n":
                out.append("\n"); i += 2; continue
            if nxt == "t":
                out.append("\t"); i += 2; continue
            if nxt == '"':
                out.append('"'); i += 2; continue
            if nxt == "\\":
                out.append("\\"); i += 2; continue
            # Keep \(…\) and other escapes as written in source.
            out.append(s[i]); i += 1; continue
        out.append(s[i]); i += 1
    return "".join(out)


def extract() -> set[str]:
    values: set[str] = set()
    for path in COACH_DIR.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        for pat in BI_PATTERNS:
            for m in pat.finditer(text):
                values.add(unescape(m.group(1)))
    app_text = (ROOT / "WeekFit" / "Localization" / "AppText.swift").read_text(encoding="utf-8")
    for m in re.finditer(r'\(\s*\n\s*"((?:\\.|[^"\\])*)"\s*,\s*\n\s*"((?:\\.|[^"\\])*)"', app_text):
        values.add(unescape(m.group(1)))
    values.discard("")
    return values


def swift_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def has_cjk(s: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", s or ""))


def translate_one(text: str) -> str:
    import os

    os.environ.setdefault("translators_default_region", "CN")
    import translators as ts

    placeholders: list[str] = []

    def protect(match: re.Match[str]) -> str:
        placeholders.append(match.group(0))
        return f" XPH{len(placeholders) - 1}X "

    protected = PLACEHOLDER_RE.sub(protect, text)
    last_error: Exception | None = None
    zh: str | None = None
    for engine in ("sogou", "iciba", "alibaba"):
        try:
            candidate = ts.translate_text(
                protected,
                translator=engine,
                from_language="en",
                to_language="zh",
            )
            if isinstance(candidate, str) and candidate.strip() and not re.fullmatch(r"[a-z0-9]{10,}", candidate.strip()):
                zh = candidate
                break
            last_error = ValueError(f"bad translation from {engine}: {candidate!r}")
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            continue
    if zh is None:
        raise last_error or ValueError(f"empty translation for {text!r}")

    for idx, token in enumerate(placeholders):
        zh = re.sub(rf"\s*XPH{idx}X\s*", token, zh)
    if re.search(r"XPH\d+X", zh):
        raise ValueError(f"placeholder leftover: {text!r} -> {zh!r}")
    src_ph = PLACEHOLDER_RE.findall(text)
    dst_ph = PLACEHOLDER_RE.findall(zh)
    if sorted(src_ph) != sorted(dst_ph):
        raise ValueError(f"placeholder mismatch: {text!r} -> {zh!r}")
    if not has_cjk(zh) and re.search(r"[A-Za-z]", text):
        raise ValueError(f"no CJK in translation: {text!r} -> {zh!r}")
    return zh


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--translate-only", action="store_true")
    parser.add_argument("--retry-missing", action="store_true",
                        help="Re-translate entries without CJK even if cached")
    args = parser.parse_args()

    from zh_hans_curated_coach import CURATED

    cache: dict[str, str] = {}
    if CACHE.exists():
        cache = json.loads(CACHE.read_text(encoding="utf-8"))
    cache.update(CURATED)

    values = sorted(extract())
    print(f"Extracted {len(values)} unique English Coach strings", flush=True)

    if not args.apply or args.translate_only or args.limit is not None or args.retry_missing:
        if args.retry_missing:
            pending = [v for v in values if not has_cjk(cache.get(v, ""))]
        else:
            pending = [v for v in values if v not in cache]
        if args.limit is not None:
            pending = pending[: args.limit]
        print(f"Translating {len(pending)}…", flush=True)
        for i, en in enumerate(pending, 1):
            try:
                if not re.search(r"[A-Za-z]", en):
                    cache[en] = en
                else:
                    cache[en] = translate_one(en)
            except Exception as exc:  # noqa: BLE001
                print("fail", en[:90], exc, flush=True)
                time.sleep(1.0)
            else:
                time.sleep(0.3)
            if i % 25 == 0:
                cache.update(CURATED)
                CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                print(f"  {i}/{len(pending)}  cjk_total={sum(1 for v in values if has_cjk(cache.get(v,'')))}", flush=True)
                time.sleep(1.0)
        cache.update(CURATED)
        CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if args.apply and not args.translate_only:
        cache.update(CURATED)
        lines = [
            "import Foundation",
            "",
            "/// Auto-generated English → zh-Hans map for Coach bilingual strings.",
            "/// Curated entries from scripts/zh_hans_curated_coach.py take precedence.",
            "enum CoachChineseOverridesTable {",
            "    static let entries: [String: String] = [",
        ]
        covered = 0
        for en in sorted(values):
            zh = cache.get(en, en)
            if has_cjk(zh):
                covered += 1
            lines.append(f'        "{swift_escape(en)}": "{swift_escape(zh)}",')
        for en, zh in sorted(CURATED.items()):
            if en not in values:
                lines.append(f'        "{swift_escape(en)}": "{swift_escape(zh)}",')
                if has_cjk(zh):
                    covered += 1
        lines.append("    ]")
        lines.append("}")
        lines.append("")
        OUT.write_text("\n".join(lines), encoding="utf-8")
        print(f"Wrote {OUT} ({covered} with CJK of {len(values)} extracted)", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
