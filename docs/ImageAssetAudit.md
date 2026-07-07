# WeekFit Image & Icon Audit

Last updated: Jul 7, 2026

## Summary

| Area | Status |
|------|--------|
| Drinks & snacks (`drinks_snacks.json`) | All assets present, transparent |
| Ingredients (meal builder) | 60/60 transparent |
| Workouts / recovery / habits | Backgrounds removed (34 assets batch-fixed) |
| Meal hero images | Backgrounds removed |
| Rendering pipeline | `PremiumAssetImage` introduced for thumbnails |
| Legacy duplicate assets | 18 orphaned imagesets remain (cleanup backlog) |

## Art Direction

Premium food/activity icons should be:

- Photorealistic cutouts on **transparent** backgrounds
- Centered subject, soft studio lighting
- Displayed with **`scaledToFit`** inside a subtle plate (`white 4%` fill), not `scaledToFill` rectangles
- No multiply/vignette overlays on transparent assets

Intentionally opaque: `weekfit-bg` (login hero), `AppIcon`.

## Fixes Applied

1. **Transparency batch pass** — `Scripts/process_asset_backgrounds.py` removed solid backgrounds from 34 opaque PNGs (workouts, habits, recovery, meals).
2. **`PremiumAssetImage`** — shared component for quick log, activity cards, planner picker, meal rows.
3. **Removed multiply gradient** from `QuickLogRowView` image wells.
4. **`FastFuelSuggestionService`** — canonical asset names (`ingredient-water`, `ingredient-tea`, `recovery-walk`, etc.).
5. **Timeline avatars** — `scaledToFit` instead of `scaledToFill` for bundle assets.

## Surfaces Using Premium Pipeline

| Surface | Component |
|---------|-----------|
| Quick log drinks/snacks | `PremiumAssetImage(.quickLogThumbnail)` |
| Quick log saved meals (asset) | `PremiumAssetImage(.quickLogThumbnail)` |
| Activity start cards | `PremiumAssetImage(.activityThumbnail)` |
| Planner add-activity picker | `PremiumAssetImage(.activityThumbnail)` |
| Meal card rows | `PremiumAssetImage(.mealCard)` |
| Plan timeline nutrition avatar | `scaledToFit` cutout |
| Meal library hero | `scaledToFit` cutout |

## Backlog (non-blocking)

- Rename `Image.png` / `ChatGPT Image …` files to canonical names
- Fix typo `recovery-orane-juice` → `recovery-orange-juice`
- Remove 18 orphaned legacy imagesets (`apple`, `banana`, `water-bottle`, …)
- Re-export any meal hero with visible background halos at higher quality
- Wire `Scripts/check_asset_transparency.sh` into CI

## Maintenance

```bash
# Verify all UI PNGs have alpha
./Scripts/check_asset_transparency.sh

# Fix newly added opaque assets
python3 Scripts/process_asset_backgrounds.py
```
