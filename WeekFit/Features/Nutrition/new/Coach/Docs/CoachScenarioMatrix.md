# Coach Scenario Matrix

> Pipeline: `CoachContext` → `CoachScenarioResolution` → `CoachTodayInsight` → `CoachCopyRegistry` → `CoachTabPresentationBridge`

```
CoachEngine.evaluate()
├── context: CoachContext
├── resolution: CoachScenarioResolution
│   ├── scenario: CoachScenarioKey      ← primary story (34 keys)
│   ├── modifiers: CoachScenarioModifiers
│   └── safetyAlert: CoachSafetyAlert?  ← overlay only; never replaces scenario
├── todayInsight: CoachTodayInsight
└── copyPack: CoachCopyPack
```

---

## Guard rules

| # | Rule | Enforcement |
|---|------|-------------|
| G1 | `fuelBehind` / `hydrationBehind` **must not** change `ScenarioKey` | Resolver + unit tests |
| G2 | `dayLoad` lives **only** in `modifiers.dayLoad` | Flat story keys |
| G3 | `safetyAlert` is optional overlay during active stress | Computed after scenario |
| G4 | `semanticColor` = primary story only | `CoachPresentationResolver` |
| G5 | `alertSeverity` = risk only, independent from color | `.elevated` = behind; `.critical` = safetyAlert |

---

## 34 ScenarioKey

### Global (6)
- `stableDay` · `morningReadiness` · `tomorrowProtection`
- `protectTomorrowFresh` · `recoveryAfterHeavyYesterday` · `lowRecoveryPrep`

### Endurance (5)
- `activeEndurance` · `duringEndurance` · `postEnduranceImmediate` · `postEnduranceSettled` · `eveningAfterEndurance`

### Racket (5)
- `activeRacket` · `duringRacket` · `postRacketImmediate` · `postRacketSettled` · `eveningAfterRacket`

### Strength (5)
- `activeStrength` · `duringStrength` · `postStrengthImmediate` · `postStrengthSettled` · `eveningAfterStrength`

### Walk (4)
- `walkLightDay` · `walkAfterHeavyLoad` · `walkEveningWindDown` · `walkRecoveryAction`

### Mindful recovery (5)
- `activeRecovery` · `duringRecovery` · `postRecoveryImmediate` · `postRecoverySettled` · `eveningAfterRecovery`

### Heat (3)
- `saunaPreparation` · `saunaActive` · `saunaRecovery`

---

## Copy intelligence layers

| Layer | Role |
|-------|------|
| **Scenario base pack** | Primary story by phase + activity family |
| **Body state overlay** | Adjusts tone for fatigued/veryFatigued (endurance, strength, racket, walk, stable) |
| **Stable day profile** | Sub-profiles: emptyDay, workBanked, lowRecoveryRest, tomorrowReserve |
| **Stacked day risk** | Supporting signal + alert severity during live serious training on heavy stacked days |
| **Tomorrow workout** | Personalizes `tomorrowProtection` / `protectTomorrowFresh` with calendar title (no clock in assessment) |
| **Supporting signals** | Up to 3 contextual “why” lines — nutrition, recovery, yesterday load |
| **Warning layer** | `fuelCritical` / `hydrationCritical` only — never in main story (G1) |

---

## safetyAlert rules

| Alert | When | Active scenarios |
|-------|------|------------------|
| `hydrationCritical` | hydration critical | `duringEndurance`, `duringRacket`, `saunaActive` |
| `fuelCritical` | fuel critical | `duringEndurance` (long/extended only) |

---

## File map

```
Coach/
├── Core/CoachEngine.swift
├── Context/CoachScenarioKey.swift
├── Context/CoachScenarioResolver.swift
├── Copy/CoachCopyRegistry.swift
├── Copy/CoachBodyStateCopyRenderer.swift
├── Copy/CoachCopyQualityAudit.swift
├── Copy/CoachCopySubjectGuard.swift
├── Presentation/CoachTodayInsight.swift
├── Presentation/CoachTabPresentationBridge.swift
└── Docs/CoachEdgeCaseMatrix.md
```

---

## Test coverage

| Suite | Scope |
|-------|-------|
| `CoachScenarioTests` | Guard rules G1–G5 |
| `CoachEdgeCaseSnapshotTests` | Ownership matrix §1–§16 |
| `CoachCopyQualityTests` | Baseline audit + modifier guards |
| `CoachBodyStateCopyTests` | Body state overlays |
| `CoachSelectionMatrixTests` | Focus/phase consistency |
