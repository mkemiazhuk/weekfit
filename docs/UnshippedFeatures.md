# Unshipped Features

These modules remain in the app target for development but are **not exposed in the production tab shell**.

| Feature | Status | Entry point |
|---------|--------|-------------|
| **Insights** | Built, not in navigation | `InsightsView.swift` (~7.5k LOC); tab commented out in `WeekFitBottomBar.swift` and `WeekFitRootView.swift` |
| **Highlights** | Built, not in navigation | `HighlightsView.swift`; tab commented out in `WeekFitBottomBar.swift` |

**Shipping tabs today:** Today, Coach, Meals, Plan.

Do not treat Insights or Highlights as user-facing product surface until they are re-enabled in navigation and pass localization/accessibility review.
