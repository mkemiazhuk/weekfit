# Phase 2 — Daily Energy Demand

Status: proposal only. No engine rewrite in Phase 1.

## Goal

Evolve WeekFit from reactive Active Energy compensation to an explainable coaching model:

```
Daily Energy Demand =
  Base Energy
+ Structured Training Demand
+ Recovery Modifier
+ Tomorrow Preparation
+ Goal Modifier
```

The user should understand *why* today’s number changed. The coach should explain it in plain language.

## Principles

1. **Do not use raw Active Energy as the main driver.** HealthKit Active Energy remains a calibration/fallback signal, not the budget formula.
2. **Separate structured training from incidental movement.** Office steps and a 90-minute ride should not affect demand the same way.
3. **Modality matters.** Endurance, strength, walk, recovery, and rest days get different demand and macro emphasis.
4. **Tomorrow influences today.** Hard sessions tomorrow should change tonight’s guidance before they appear in HealthKit burn totals.
5. **Keep the model explainable.** Every adjustment should map to one visible reason.

## Proposed components

| Component | Purpose | Example user-facing reason |
|-----------|---------|----------------------------|
| **Base Energy** | Resting need + small lifestyle floor | “Your daily baseline” |
| **Structured Training Demand** | Planned/completed sessions by type | “Today’s strength session” |
| **Recovery Modifier** | Sleep, HRV, recent load | “Recovery is low — protecting fuel today” |
| **Tomorrow Preparation** | Back-propagated demand from planner | “Hard ride tomorrow — fuel tonight” |
| **Goal Modifier** | When deficit/surplus applies | “Fat-loss day on a rest day” |

## Modality treatment (initial policy)

| Session type | Demand | Macro emphasis |
|--------------|--------|----------------|
| Endurance (long) | Higher total demand | Carbs around and after session |
| Strength | Moderate demand | Protein after session |
| Walk / easy movement | Low demand | Mostly covered by base |
| Recovery / mobility | Minimal add-on | Hydration first |
| Rest day | No training add-on | Best day for goal deficit |

## What stays from Phase 1

- `NutritionBudgetCalculator` as the single display source
- BMR anchor and goal enum
- Coach scenario layer, but fed by demand outputs instead of parallel heuristics

## What Phase 2 adds

1. **Demand engine** that outputs `DailyDemandPlan` instead of `BMR + active × factor`
2. **Planner integration** so tomorrow’s sessions affect today’s guidance
3. **Explainability layer** — each adjustment becomes one line of coach copy
4. **Budget adapter** — `NutritionBudgetCalculator` consumes demand plan totals, preserving one UI source of truth

## Out of scope for Phase 2

- Full glycogen modeling
- Multi-day energy ledger
- Weight-trend expenditure solving
- Meal-plan generation rewrite

## Success criteria

- Today ring and remaining calories reflect demand plan, not `target + active`
- Users can answer: “Why is my target X today?”
- Hard training days feel proactively supported, not reactively inflated by HealthKit
- Rest/low-recovery days stop feeling like “free extra calories” after normal movement

## Suggested rollout

1. Ship demand plan behind the existing budget calculator interface
2. Start with structured training + tomorrow preparation only
3. Add recovery modifier next
4. Keep Active Energy as validation, not the primary driver
