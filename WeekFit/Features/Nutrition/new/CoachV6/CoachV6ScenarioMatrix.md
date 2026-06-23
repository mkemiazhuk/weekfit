# CoachV6 Scenario Matrix (v3 — guard audit)

> Model complete. CopyRegistry **not started**.  
> Pipeline: `CoachV6Context` → `CoachV6ScenarioResolution` → `CoachV6TodayInsight` → CopyPack *(future)*

```
CoachV6Engine.evaluate()
├── context: CoachV6Context
├── resolution: CoachV6ScenarioResolution
│   ├── scenario: CoachV6ScenarioKey      ← primary story (30 keys)
│   ├── modifiers: CoachV6ScenarioModifiers
│   └── safetyAlert: CoachV6SafetyAlert?  ← overlay only; never replaces scenario
└── todayInsight: CoachV6TodayInsight
    ├── scenario + modifiers (same as resolution)
    ├── semanticColor                     ← story chrome (scenario-driven)
    ├── alertSeverity                     ← risk chrome (modifier/alert-driven)
    ├── safetyAlert
    ├── icon
    └── urgencyLevel
```

---

## Guard rules (fixed before CopyRegistry)

| # | Rule | Enforcement |
|---|------|-------------|
| G1 | `fuelBehind` / `hydrationBehind` **must not** change `ScenarioKey` | Resolver ignores nutrition in `primaryScenario`; unit tests |
| G2 | `dayLoad` lives **only** in `modifiers.dayLoad`, never in key names | 30 flat story keys; `testDayLoadLivesOnlyInModifiers` |
| G3 | `safetyAlert` is optional overlay during active stress | Computed **after** scenario; never feeds back |
| G4 | `semanticColor` = primary story only | `CoachV6PresentationResolver.semanticColor(for:)` reads scenario only |
| G5 | `alertSeverity` = risk only, independent from color | `.elevated` = behind modifiers; `.critical` = safetyAlert |

---

## 30 ScenarioKey (complete list)

### Global (3)
- `stableDay`
- `morningReadiness`
- `tomorrowProtection`

### Endurance — Cycling, Running (5)
- `activeEndurance` · `duringEndurance` · `postEnduranceImmediate` · `postEnduranceSettled` · `eveningAfterEndurance`

### Racket — Tennis, Squash (5)
- `activeRacket` · `duringRacket` · `postRacketImmediate` · `postRacketSettled` · `eveningAfterRacket`

### Strength (5)
- `activeStrength` · `duringStrength` · `postStrengthImmediate` · `postStrengthSettled` · `eveningAfterStrength`

### Walk (4)
- `walkLightDay` — light walk, ordinary day
- `walkAfterHeavyLoad` — walk when day load moderate+
- `walkEveningWindDown` — evening / late-evening walk
- `walkRecoveryAction` — walk as recovery step after serious work

### Mindful recovery — Stretch / Yoga / Breath (5)
- `activeRecovery` · `duringRecovery` · `postRecoveryImmediate` · `postRecoverySettled` · `eveningAfterRecovery`

### Heat — Sauna (3)
- `saunaPreparation` · `saunaActive` · `saunaRecovery`

**Total: 30**

---

## Modifiers (`CoachV6ScenarioModifiers`)

| Field | Type | Role |
|-------|------|------|
| `dayLoad` | fresh · moderate · heavy · extreme | Protection vs performance copy blocks |
| `fuelBehind` | Bool | Support signal — **not** a scenario |
| `hydrationBehind` | Bool | Support signal — **not** a scenario |
| `tomorrowDemand` | none · easy · moderate · hard | Tomorrow framing |
| `activityType` | CoachV6ActivityType | Sport-specific wording |
| `durationBand` | short · medium · long · extended | Session length |
| `completedSeriousActivities` | none · one · twoOrMore | Stacked-day context |
| `timeOfDay` | morning … night | Cadence |

Day load bands (max signal wins):

| Band | Signals |
|------|---------|
| fresh | No serious work; low kcal / volume |
| moderate | One serious done; 400–700 kcal; 60–90 min |
| heavy | Stacked work; 700–1200 kcal; 90–240 min |
| extreme | Two+ serious + active; 1200+ kcal; 240+ min |

---

## safetyAlert rules

Computed **after** scenario. Never replaces scenario.

| Alert | When | Active scenarios |
|-------|------|------------------|
| `hydrationCritical` | `hydrationState == .critical` | `duringEndurance`, `duringRacket`, `saunaActive` |
| `fuelCritical` | `fuelState == .critical` | `duringEndurance` (long/extended only) |

**Behind vs critical (nutrition engine):**

| State | Hydration | Fuel |
|-------|-----------|------|
| behind | progress < 50% or ≥ 1.0 L remaining | calories < 45% **and** protein < 55% |
| critical | progress < 25% or ≥ 1.5 L remaining | long/extended endurance **and** calories < 30% |

Example: 100 km ride + hydration behind → `duringEndurance` + `hydrationBehind: true` + `alertSeverity: .elevated` + **no** safetyAlert.

Example: same ride + hydration critical → `duringEndurance` + `safetyAlert: .hydrationCritical` + `alertSeverity: .critical`.

Example: stable day + fuel behind → `stableDay` + `fuelBehind: true` + `semanticColor: .stable` + `alertSeverity: .elevated`.

---

## semanticColor rules (story layer)

Driven **only** by `ScenarioKey`. Ignores modifiers.

| semanticColor | Scenarios |
|---------------|-----------|
| `stable` | `stableDay`, `walkEveningWindDown` |
| `ready` | `morningReadiness` |
| `activity` | `active*`, `post*Immediate` (training families) |
| `live` | `during*` (endurance, racket, strength, recovery) |
| `recovery` | `post*Settled`, `eveningAfter*`, walk (except wind-down), `saunaRecovery` |
| `protection` | `tomorrowProtection` |
| `heat` | `saunaPreparation`, `saunaActive` |

---

## alertSeverity rules (risk layer)

Independent from `semanticColor`.

| Severity | Condition |
|----------|-----------|
| `none` | No behind modifiers, no safetyAlert |
| `elevated` | `fuelBehind` or `hydrationBehind`, no safetyAlert |
| `critical` | `safetyAlert != nil` |

A card can be `.semanticColor = .live` (endurance story) **and** `.alertSeverity = .elevated` (hydration behind) simultaneously.

---

## urgencyLevel rules

| Level | Typical scenarios |
|-------|-------------------|
| `calm` | stable, morning, settled post, wind-down walk |
| `focused` | pre-session, immediate post |
| `live` | during active session |
| `protective` | tomorrow protection, evening-after training |
| `critical` | safetyAlert present |

---

## Walk resolver priority

1. `walkEveningWindDown` — evening phase or evening/late-evening time
2. `walkRecoveryAction` — serious work done + pre/during/immediate post
3. `walkAfterHeavyLoad` — day load moderate+
4. `walkLightDay` — default

---

## Today Coach Insight contract

`CoachV6TodayInsight` is the surface bundle for Today teaser / insight row:

```swift
struct CoachV6TodayInsight {
    let scenario: CoachV6ScenarioKey
    let modifiers: CoachV6ScenarioModifiers
    let semanticColor: CoachV6SemanticColor
    let alertSeverity: CoachV6AlertSeverity
    let safetyAlert: CoachV6SafetyAlert?
    let icon: String          // SF Symbol
    let urgencyLevel: CoachV6UrgencyLevel
}
```

Produced by `CoachV6PresentationResolver.todayInsight(resolution:context:)`.  
Wired through `CoachV6Engine.evaluate()` → `Result.todayInsight`.

---

## File map

```
CoachV6/
├── CoachV6Context.swift
├── CoachV6ScenarioKey.swift       — ScenarioKey + Modifiers + Resolution
├── CoachV6ScenarioResolver.swift  — guard rules + primaryScenario
├── CoachV6TodayInsight.swift      — presentation + semanticColor / alertSeverity
├── CoachV6Engine.swift
└── CoachV6ScenarioMatrix.md
```

**Not yet:** CopyRegistry, CopyPack, UI wiring.

---

## Test coverage (`CoachV6ScenarioTests`)

| Test | Guard |
|------|-------|
| Endurance + hydration behind | G1, G4, G5 |
| Endurance + hydration critical | G3 |
| Fuel behind on stable day | G1, G4, G5 |
| Fuel behind vs adequate — same scenario | G1 |
| Day load fresh vs heavy — same scenario key | G2 |
| Tomorrow protection | story |
| Walk after heavy load | story |
| Walk evening wind-down | story |
| Sauna active | story |
