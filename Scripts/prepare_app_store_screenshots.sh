#!/usr/bin/env bash
# Prepare manual iPhone screenshots for App Store Connect.
# Usage: ./Scripts/prepare_app_store_screenshots.sh [source_dir]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="${1:-/Users/maxk/.cursor/projects/Users-maxk-Dev-WeekFit/assets}"
OUT="$ROOT/build/app-store-screenshots/manual"

mkdir -p "$OUT/6.7-inch" "$OUT/6.5-inch" "$OUT/6.1-inch" "$OUT/source"

# slug|caption|source filename
SCENES=(
  "01-today|Your day, interpreted|image-c11c2b6a-7fdf-4d85-a9b3-6e4eb1177ac6.png"
  "02-coach|Know what to do next|image-66a80110-33a9-4743-b66a-d5d17da9d0eb.png"
  "03-plan|See your whole day|image-5a1a2f43-7f39-467a-bf77-95dabbd441ee.png"
  "04-meals|Eat in context|image-540d2f40-9a7d-49a7-a82a-65b704d505cb.png"
  "05-build-meal|Build meals in seconds|image-c70341db-15a4-4d30-886a-4768e4de3cbf.png"
  "06-walk-details|Stays in sync with Apple Watch|image-6de29061-dc3f-4520-a99f-8dc62b792708.png"
  "07-recovery|Recovery at a glance|image-b61e55cd-4db2-480d-ab45-725b0a01d9b3.png"
  "08-activity-score|Activity score and trends|image-5e15c2e4-e8c6-4696-8011-9e927358ee1a.png"
  "09-nutrition|Nutrition quality breakdown|image-1fb53f46-0e49-4998-a81a-806c4a741018.png"
  "10-activity-picker|Plan workouts fast|image-552ea42e-bf6f-4925-be26-f31d96eb0a44.png"
)

resize_to() {
  local src="$1" dst="$2" h="$3" w="$4"
  cp "$src" "$dst"
  sips -z "$h" "$w" "$dst" >/dev/null
}

echo "→ Preparing App Store screenshots"
echo "  Source: $SOURCE_DIR"
echo "  Output: $OUT"

for entry in "${SCENES[@]}"; do
  IFS='|' read -r slug _caption filename <<< "$entry"
  src="$SOURCE_DIR/$filename"
  if [[ ! -f "$src" ]]; then
    echo "⚠ Missing: $filename" >&2
    continue
  fi

  cp "$src" "$OUT/source/${slug}.png"
  resize_to "$src" "$OUT/6.7-inch/${slug}.png" 2796 1290
  resize_to "$src" "$OUT/6.5-inch/${slug}.png" 2778 1284
  # App Store Connect 6.1" slot expects 1170×2532.
  resize_to "$src" "$OUT/6.1-inch/${slug}.png" 2532 1170
  echo "  ✓ $slug"
done

cat > "$OUT/UPLOAD.md" <<'EOF'
# WeekFit — App Store Screenshots

Upload **01–08** to App Store Connect (09–10 optional).

| # | File | Caption (EN) |
|---|------|--------------|
| 1 | `01-today.png` | Your day, interpreted |
| 2 | `02-coach.png` | Know what to do next |
| 3 | `03-plan.png` | See your whole day |
| 4 | `04-meals.png` | Eat in context |
| 5 | `05-build-meal.png` | Build meals in seconds |
| 6 | `06-walk-details.png` | Stays in sync with Apple Watch |
| 7 | `07-recovery.png` | Recovery at a glance |
| 8 | `08-activity-score.png` | Activity score and trends |

## Folders

- `6.7-inch/` — iPhone 6.7" display (**1290×2796**)
- `6.5-inch/` — iPhone 6.5" display (**1284×2778**)
- `6.1-inch/` — iPhone 6.1" display (**1170×2532**)

## App Store Connect

1. **App Store → Screenshots**
2. Upload `6.7-inch/` files for **6.7" Display**
3. Upload `6.5-inch/` files for **6.5" Display**
4. Upload `6.1-inch/` files for **6.1" Display**
5. Same order on all sizes

## Better quality

Chat previews are low resolution. For crisp store images, export originals from iPhone:
**Photos → select screenshots → Share → Save to Files / AirDrop to Mac**

Then replace files in `source/` (or pass a folder):

```bash
./Scripts/prepare_app_store_screenshots.sh ~/Downloads/WeekFit-Screenshots
```

Name files `01-today.png`, `02-coach.png`, … or keep UUID names in a mapping folder.
EOF

echo "✓ Done → $OUT"
