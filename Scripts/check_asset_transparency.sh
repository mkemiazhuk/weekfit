#!/usr/bin/env bash
set -euo pipefail

ASSETS_ROOT="${1:-WeekFit/Resources/Assets.xcassets}"
ALLOW_OPAQUE=("weekfit-bg.imageset" "AppIcon.appiconset")

failures=0

while IFS= read -r -d '' png; do
  rel="${png#${ASSETS_ROOT}/}"
  for allowed in "${ALLOW_OPAQUE[@]}"; do
    if [[ "$rel" == "$allowed"* ]]; then
      continue 2
    fi
  done

  alpha="$(magick identify -format '%A' "$png")"
  if [[ "$alpha" != "Blend" ]]; then
    echo "opaque: $rel"
    failures=$((failures + 1))
  fi
done < <(find "$ASSETS_ROOT" -name '*.png' -print0)

if [[ "$failures" -gt 0 ]]; then
  echo "Found $failures opaque PNG(s). Run Scripts/process_asset_backgrounds.py to fix."
  exit 1
fi

echo "All UI PNG assets have transparency."
