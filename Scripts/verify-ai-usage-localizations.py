#!/usr/bin/env python3
"""Check the AI usage catalog against all app languages and referenced keys."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'WeekFit/Localization/AppLanguage.swift').read_text().split('var id:')[0]
languages = set(re.findall(r'case \w+ = "([^"]+)"', source))
catalog = json.loads((root / 'WeekFit/AIUsage.xcstrings').read_text())['strings']
used = set()
for path in (root / 'WeekFit').rglob('*.swift'):
    used.update(re.findall(r'"(ai\.usage\.[A-Za-z]+)"', path.read_text()))
assert used <= catalog.keys(), f'Missing keys: {used - catalog.keys()}'
for key, entry in catalog.items():
    assert languages <= entry['localizations'].keys(), f'{key}: missing language'
    for language in languages:
        unit = entry['localizations'][language]['stringUnit']
        assert unit['state'] == 'translated' and unit['value'].strip(), f'{key}: {language}'
print(f'AI usage: {len(used)} referenced keys; {len(catalog)} translated keys; {len(languages)} languages.')
