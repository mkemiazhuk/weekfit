#!/usr/bin/env bash
# Prepare native iPhone 15 screenshots for App Store Connect.
# Usage: ./Scripts/prepare_iphone15_screenshots.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/app-store-screenshots/manual/iphone-15"
OUT="$ROOT/build/app-store-screenshots/manual/final"

mkdir -p "$OUT/6.1-inch" "$OUT/6.7-inch"

# source file|output slug
SCENES=(
  "IMG_0630.PNG|01-today"
  "IMG_0631.PNG|02-coach"
  "IMG_0633.PNG|03-plan"
  "IMG_0632.PNG|04-meals"
  "IMG_0636.PNG|05-recovery"
  "IMG_0634.PNG|06-activity-score"
  "IMG_0626.PNG|07-nutrition"
  "IMG_0621.PNG|08-meal-details"
)

echo "→ Preparing App Store screenshots from iPhone 15 originals"
echo "  Source: $SRC"

for entry in "${SCENES[@]}"; do
  IFS='|' read -r file slug <<< "$entry"
  src="$SRC/$file"
  if [[ ! -f "$src" ]]; then
    echo "⚠ Missing: $file" >&2
    continue
  fi

  cp "$src" "$OUT/6.1-inch/${slug}.png"
  cp "$src" "$OUT/6.7-inch/${slug}.png"
  sips -z 2796 1290 "$OUT/6.7-inch/${slug}.png" >/dev/null

  w=$(sips -g pixelWidth "$OUT/6.1-inch/${slug}.png" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$OUT/6.1-inch/${slug}.png" | awk '/pixelHeight/{print $2}')
  echo "  ✓ $slug (${w}×${h} → 6.1\", scaled → 6.7\")"
done

cat > "$OUT/UPLOAD.md" <<'EOF'
# WeekFit — App Store Screenshots (native iPhone 15)

## Upload order

| # | File | Screen |
|---|------|--------|
| 1 | `01-today.png` | Today |
| 2 | `02-coach.png` | Coach |
| 3 | `03-plan.png` | Plan |
| 4 | `04-meals.png` | Saved Meals |
| 5 | `05-recovery.png` | Recovery details |
| 6 | `06-activity-score.png` | Activity details |
| 7 | `07-nutrition.png` | Nutrition details |
| 8 | `08-meal-details.png` | Meal details |

## Folders

- **`6.1-inch/`** — upload as-is → **6.1" Display** (1179×2556)
- **`6.7-inch/`** — upload → **6.7" Display** (1290×2796, scaled from same iPhone shots)

## App Store Connect

1. App Store → Screenshots
2. **6.1" Display** ← drag files from `6.1-inch/` in order 01–08
3. **6.7" Display** ← drag files from `6.7-inch/` in same order

## Extra sources (not in main set)

Left in `iphone-15/` if you want to swap later:
- `IMG_0635.PNG` — Nutrition (Jun 26)
- `IMG_0599.PNG` — older nutrition capture
EOF

echo "✓ Ready → $OUT"
