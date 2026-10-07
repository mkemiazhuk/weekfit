#!/usr/bin/env python3
"""Export EN→zh-Hans workbooks for human translators (not machine translation).

Produces CSV packs under scripts/human_i18n/:
  - coach_remaining.csv / coach_all.csv
  - ui_priority.csv / ui_all.csv

Columns: key_or_source, english, russian_hint, chinese, notes, status
  status: needs_human | draft_mt | curated | keep

Usage:
  /tmp/weekfit-i18n/bin/python Scripts/export_zh_hans_human_pack.py
"""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "scripts" / "human_i18n"
sys.path.insert(0, str(ROOT / "Scripts"))

from generate_coach_chinese_overrides import extract as extract_coach  # noqa: E402
from translate_xcstrings_zh_hans import CATALOGS, collect_english, load_cache, should_keep  # noqa: E402
from zh_hans_curated_coach import CURATED  # noqa: E402


def cjk(s: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", s or ""))


STYLE_NOTES = """
WeekFit zh-Hans style (for human translators)
=============================================
Tone: supportive fitness assistant — natural, concise, warm, never clinical or preachy.
Prefer short sentences. Avoid literal English calques and repetitive wording.
Keep: WeekFit, Coach, HRV, REM, BMI, kcal, BPM, product IDs, analytics names.
Preserve placeholders exactly: %@ %lld %1$@ \\(name) etc. Never reorder named Swift interpolations incorrectly.
Units: keep user's unit system; don't invent health conclusions.
Feelings chips: Okay→还行, Tired→疲惫, Energized→精力充沛, Low→不太好.
Topics: Activity→活动, Nutrition→营养, Recovery→恢复.
Tabs: Today→今天, Meals→饮食, Plan→计划, Insights→洞察.
English is the source of truth. Russian is a meaning hint only when helpful.
"""


def load_ru_map() -> dict[str, str]:
    """english value -> russian value from Localizable.xcstrings where available."""
    mapping: dict[str, str] = {}
    for path in CATALOGS:
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        for entry in data.get("strings", {}).values():
            locs = entry.get("localizations") or {}
            en = (locs.get("en") or {}).get("stringUnit", {}).get("value")
            ru = (locs.get("ru") or {}).get("stringUnit", {}).get("value")
            if en and ru:
                mapping[en] = ru
    return mapping


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = ["english", "russian_hint", "chinese", "status", "notes"]
    with path.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "STYLE_NOTES.txt").write_text(STYLE_NOTES.strip() + "\n", encoding="utf-8")

    ru_map = load_ru_map()
    ui_cache = load_cache()
    coach_cache = {}
    coach_cache_path = ROOT / "scripts" / ".coach_zh_hans_cache.json"
    if coach_cache_path.exists():
        coach_cache = json.loads(coach_cache_path.read_text(encoding="utf-8"))
    coach_cache.update(CURATED)

    # --- Coach pack ---
    coach_rows = []
    for en in sorted(extract_coach()):
        zh = coach_cache.get(en, "")
        if en in CURATED:
            status = "curated"
        elif cjk(zh):
            status = "draft_mt"  # needs native pass
        else:
            status = "needs_human"
            zh = ""
        coach_rows.append(
            {
                "english": en,
                "russian_hint": "",
                "chinese": zh if status != "needs_human" else "",
                "status": status,
                "notes": "Coach/Assistant dialogue — prioritize natural spoken tone",
            }
        )
    write_csv(OUT / "coach_all.csv", coach_rows)
    write_csv(
        OUT / "coach_needs_native_review.csv",
        [r for r in coach_rows if r["status"] in ("draft_mt", "needs_human")],
    )

    # --- UI pack ---
    priority_terms = re.compile(
        r"^(Today|Coach|Meals|Plan|Insights|Settings|Language|Subscribe|Restore|"
        r"Activity|Nutrition|Recovery|Sleep|Protein|Calories|Water|Done|Cancel|Save|"
        r"How are you|Good morning|Good afternoon|Good evening|Open Meals|What’s left|"
        r"Next meal|Loading|Try again|Allow|Continue|Premium)",
        re.I,
    )
    ui_rows = []
    for en in sorted(collect_english(CATALOGS)):
        if should_keep(en):
            ui_rows.append(
                {
                    "english": en,
                    "russian_hint": ru_map.get(en, ""),
                    "chinese": en,
                    "status": "keep",
                    "notes": "brand/code/format — do not translate",
                }
            )
            continue
        zh = ui_cache.get(en, "")
        if en in CURATED and cjk(CURATED[en]):
            status, chinese = "curated", CURATED[en]
        elif cjk(zh):
            status, chinese = "draft_mt", zh
        else:
            status, chinese = "needs_human", ""
        note = "UI string"
        if priority_terms.search(en):
            note = "PRIORITY UI — tabs/onboarding/paywall/coach chrome"
        ui_rows.append(
            {
                "english": en,
                "russian_hint": ru_map.get(en, ""),
                "chinese": chinese,
                "status": status,
                "notes": note,
            }
        )
    write_csv(OUT / "ui_all.csv", ui_rows)
    write_csv(
        OUT / "ui_needs_human.csv",
        [r for r in ui_rows if r["status"] == "needs_human"],
    )
    write_csv(
        OUT / "ui_priority_needs_human.csv",
        [r for r in ui_rows if r["status"] == "needs_human" and "PRIORITY" in r["notes"]],
    )
    write_csv(
        OUT / "ui_draft_mt_for_native_edit.csv",
        [r for r in ui_rows if r["status"] == "draft_mt"],
    )

    print(f"Wrote packs to {OUT}")
    print(f"  coach_all: {len(coach_rows)} (native review: {sum(1 for r in coach_rows if r['status']!='curated')})")
    print(f"  ui_needs_human: {sum(1 for r in ui_rows if r['status']=='needs_human')}")
    print(f"  ui_draft_mt_for_native_edit: {sum(1 for r in ui_rows if r['status']=='draft_mt')}")
    print(f"  ui_priority_needs_human: {sum(1 for r in ui_rows if r['status']=='needs_human' and 'PRIORITY' in r['notes'])}")
    print("Do NOT run machine translation for final copy. Fill chinese column, then import.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
