# Coach Intelligence Audit (Jun 2026)

## Pipeline health

| Layer | Status | Notes |
|-------|--------|-------|
| Focus selection | OK | Active > upcoming serious > recent completed ≤180m |
| Scenario resolver (34 keys) | OK | G1–G5 guard rules enforced in tests |
| Day readiness / yesterday | Wired | `CoachDayReadiness` + `recoveryAfterHeavyYesterday` |
| Athlete body state | OK | Overlay on Phase 2A scenarios |
| Copy registry | OK | Activity-type aware endurance post/evening + mindful recovery |
| Presentation bridge | OK | Tab + hero copy from single pack |

## Ownership stability fixes (P1–P3)

### P1 — HealthKit `isCompleted` flicker

**Problem:** Watch sync can mark a session complete while the user is still inside the planned window → premature jump `during*` → `post*`.

**Fix:** `CoachSessionPhaseStability` in `CoachFocusResolver`:
- Treat endurance + mindful recovery as **live** while `now ≤ plannedEnd`, even when `isCompleted`.
- Short HK grace: watch-synced full completion stays live up to **5 min** after planned end.
- Strength / racket / heat: no grace — post phase follows calendar immediately after planned end.

**Tests:** `CoachOwnershipStabilityTests` (P1), `CoachEdgeCaseSnapshotTests` §16C.

### P2 — Evening protection vs upcoming today

**Problem:** `tomorrowProtection` could own the hero when a meaningful workout/recovery block was still on today's calendar.

**Fix:** `CoachUpcomingActivityPolicy.hasMeaningfulActivityLaterToday` gates both:
- `shouldPreferTomorrowProtectionOverCompletedFocus` (explicit completed focus)
- `resolveIdleSessionPhase` (auto-focus idle evening)

Meaningful = endurance, strength, racket, heat, recovery, or walk ≥20m — not meals/hydration logs.

**Tests:** `CoachOwnershipStabilityTests` (P2), edge-case §4B / §4B′.

### P3 — Stacked overlay semantics

**Problem:** `stackedDayActiveRisk` replaced the entire copy pack and Today title («Нагрузка на пределе») while scenario key stayed `during*`.

**Fix:**
- Scenario key + primary copy pack unchanged (`duringEndurance`, `activeStrength`, …).
- Stacked load surfaced via `modifiers.stackedDayActiveRisk` → supporting signal + `alertSeverity: .critical`.
- Today title / coach headline stay session-native (e.g. «Силовая идёт», «На заезде»).

**Tests:** `CoachStackedDayRiskTests`, `CoachOwnershipStabilityTests` (P3), edge-case §8.

## Remaining upgrades

| Priority | Item |
|----------|------|
| P4 | `lowRecoveryPrep` body-state overlay when very fatigued |
| P5 | Meal timing intelligence via `CoachNutritionPace` + time-of-day |

## Test matrix

```
CoachOwnershipStabilityTests   — P1–P3 targeted regression
CoachCopyQualityTests          — baseline + modifier audit
CoachEdgeCaseSnapshotTests     — ownership matrix §1–§16
CoachSelectionMatrixTests      — focus/phase/copy subject consistency
CoachScenarioTests             — guard rules + scenario routing
CoachStackedDayRiskTests       — stacked modifier presentation
```

Run before release:

```bash
xcodebuild test -scheme WeekFit -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:WeekFitTests/CoachOwnershipStabilityTests \
  -only-testing:WeekFitTests/CoachEdgeCaseSnapshotTests \
  -only-testing:WeekFitTests/CoachStackedDayRiskTests \
  -only-testing:WeekFitTests/CoachCopyQualityTests \
  -only-testing:WeekFitTests/CoachScenarioTests
```
