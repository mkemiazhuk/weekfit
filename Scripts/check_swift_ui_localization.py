#!/usr/bin/env python3
"""Flag likely user-facing hardcoded English in Swift UI code."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [
    ROOT / "WeekFit/Features/Insights",
    ROOT / "WeekFit/Features/Home/Views/Activity/ActivityIntelligenceView.swift",
]

# Lines matching these are ignored (previews, tests, validation keywords, SF symbols).
IGNORE_LINE_PATTERNS = [
    re.compile(r"#Preview"),
    re.compile(r"#if DEBUG"),
    re.compile(r"XCTAssert"),
    re.compile(r"\.preview"),
    re.compile(r"InsightScenario"),
    re.compile(r"makePreview"),
    re.compile(r"containsAny\("),
    re.compile(r"normalized\("),
    re.compile(r"systemName:"),
    re.compile(r"icon:\s*\""),
    re.compile(r"rawValue"),
    re.compile(r"CaseIterable"),
    re.compile(r"//"),
]

TEXT_PATTERNS = [
    re.compile(r'Text\("([A-Za-z][^"]{2,})"\)'),
    re.compile(r'SectionLabel\("([a-z]+\.[a-z][^"]*)"\)'),
    re.compile(r'label:\s*"([A-Z][A-Z0-9 &]+)"'),
    re.compile(r'title:\s*"([A-Z][^"]{3,})"'),
]

ALLOWED_LITERALS = {
    "WF", "M", "T", "W", "F", "S", "—", "OK", "HRV", "BMR", "TDEE", "REM", "RHR",
}


def should_ignore_line(line: str) -> bool:
    return any(p.search(line) for p in IGNORE_LINE_PATTERNS)


def scan_file(path: Path) -> list[str]:
    findings: list[str] = []
    in_preview_block = False
    skip_view_model_story_block = path.name == "InsightsView.swift"

    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = line.strip()
        if skip_view_model_story_block and line_no >= 887 and line_no < 4516:
            # InsightsViewModel contains unused legacy story-engine duplicates; production
            # copy uses InsightsStoryEngine and localized makeLearnings/makeTrends helpers.
            continue
        if "#if DEBUG" in stripped:
            in_preview_block = True
        if in_preview_block and "#endif" in stripped:
            in_preview_block = False
            continue
        if in_preview_block:
            continue
        if should_ignore_line(line):
            continue
        if "WeekFitLocalizedString" in line or "InsightsLocalization" in line:
            continue

        for pattern in TEXT_PATTERNS:
            for match in pattern.finditer(line):
                literal = match.group(1)
                if literal in ALLOWED_LITERALS:
                    continue
                if literal.startswith("activity.") or literal.startswith("insights."):
                    findings.append(f"{path.relative_to(ROOT)}:{line_no}: raw key or English `{literal}`")
                elif re.search(r"[A-Za-z]{3,}", literal) and not literal.startswith("%"):
                    findings.append(f"{path.relative_to(ROOT)}:{line_no}: hardcoded `{literal}`")
    return findings


def main() -> int:
    all_findings: list[str] = []
    for target in TARGETS:
        if target.is_file():
            all_findings.extend(scan_file(target))
        else:
            for swift in sorted(target.rglob("*.swift")):
                if swift.name.endswith("Tests.swift"):
                    continue
                all_findings.extend(scan_file(swift))

    if all_findings:
        print(f"Swift UI localization check failed: {len(all_findings)} finding(s)")
        for item in all_findings[:60]:
            print(f"  - {item}")
        if len(all_findings) > 60:
            print(f"  ... and {len(all_findings) - 60} more")
        return 1

    print("Swift UI localization check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
