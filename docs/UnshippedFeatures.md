# Unshipped Features

These modules remain in the app target for development but are **not exposed in the production tab shell**.

| Feature | Status | Entry point | Decision |
|---------|--------|-------------|----------|
| **Insights** | Built, not in navigation | `InsightsView.swift` (~7.5k LOC) | **Kill until dedicated QA sprint** — keep tab commented out |
| **Highlights** | Built, not in navigation | `HighlightsView.swift` | **Kill until dedicated QA sprint** — keep tab commented out |

**Shipping tabs today:** Today, Coach, Meals, Plan.

## Insights / Highlights policy (June 2026)

Do not re-enable Insights or Highlights in `WeekFitBottomBar` or `WeekFitRootView` until all of the following are true:

1. Localization parity passes for all user-visible strings in the module.
2. Accessibility checklist in `docs/AccessibilityPass.md` is complete for the module.
3. UI tests cover the module's primary navigation path.
4. Product signs off on positioning relative to Coach and Today.

Until then, treat these modules as **internal prototypes**, not user-facing surface.
