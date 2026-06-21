# Hydration Policy Review

**Branch:** `cursor-recover-coachengine-folder-0826`  
**Baseline:** 63 failing tests after `92a69e5` (full suite snapshot in `/tmp/weekfit-failures-63.json`)  
**Scope:** Hydration-related failures only — no engine or test changes until this review is accepted.  
**Reference contract:** Phase 3 narrative matrix (`CoachNarrativeMatrixValidationSuite`) — 0 P0 fails, calm wind-down scenarios pass with protection copy rather than deficit copy.

---

## Summary

Hydration failures split into three themes:

1. **Support-channel regression cluster** — morning/prep-window hydration no longer surfaces in `supportActions`, `supportSignals`, or resolver `supportBullets` even when water is zero and activity is later today.
2. **Primary-vs-support boundary drift** — some scenarios now put hydration in primary recommendation or hero while legacy tests expect it only in support; matrix scenario B3 expects explicit drink language in prep window but copy moved to legs/stillness framing.
3. **Evening protect-tomorrow hydration** — badge shifted from `PROTECT TOMORROW` to `RECOVER`; close-phase hydration actions (`Drink 300-500 ml fluid`) may still be correct behavior but tests expect a different badge/phase pairing.

**Recommendation:** Treat support-channel cluster as **needs product decision** before fixing — decide whether calm mornings should proactively nudge hydration or only surface it when prep/activity context exists. Treat matrix B3/G1 prep timing as **intentional new contract** if legs/stillness prep owns the hero and hydration lives in why/support.

---

## Item-by-item review

### HumanCoachDecisionEngineXCTests

| Test | Old contract | Actual behavior (from failure output) | Classification | Notes |
|------|--------------|----------------------------------------|----------------|-------|
| `testMorningLowWaterAppearsAsSupportAction` | Calm morning, zero water → `supportActions` contains `.hydrateBeforeSession` or `.steadyHydration`; hero must not mention water | `supportActions=[]` | **needs product decision** | Strong recovery + no activity: should hydration appear at all, or only when workout/sauna is scheduled? Phase 3 A1/A2 calm scenarios pass without mandatory hydration rows. |
| `testHydrationOnlyAppearsInSupportForNormalDays` | Hydration visible only in support on normal stable days | Hydration missing or elevated beyond support | **needs product decision** | Same product question as morning low water. |
| `testHydrationCannotBecomePrimaryActionOne` | Hydration must not be primary action #1 on normal days | Hydration appears as primary | **needs product decision** | If prep-window severity (water zero + ride soon) warrants primary hydration, update contract; if not, real regression. |
| `testPrepareRideShowsHydrationSupportWhenWaterZero` | Prep ride with zero water → hydration in `supportActions` (`Drink 300-500 ml water`, `Bring a bottle`), not in `primaryActions` | Support rows missing | **real regression** (if support policy unchanged) | Scenario injects explicit resolver support bullets; engine should preserve them in final story support channel. High confidence this is unintended. |
| `testPrepWindowMealLoggedButWaterZeroKeepsHydrationWarningVisible` | Meal logged but water zero in prep window → hydration warning stays visible | Warning not visible | **real regression** (if support policy unchanged) | Prep window is the strongest case for hydration support; meal logged should not suppress water gap. |
| `testSupportSignalsContainHydrationWhenRelevant` | `v5Interpretation.supportSignals` includes `.hydration` when water low + activity later | Signals empty or missing hydration | **real regression** (if signal policy unchanged) | Parallel to supportActions cluster. |
| `testSecondaryHydrationSupportUsesSoftLanguage` | Secondary hydration uses soft phrasing (not alarmist) | Missing or hard phrasing | **needs product decision** | Depends on whether support row exists at all; language review blocked on surfacing decision. |
| `testProtectTomorrowMentionsHydrationOnlyWhenFuelCovered` | Evening before hard tomorrow: badge `PROTECT TOMORROW`, hydration mentioned only when fuel covered; close-phase drink actions | Badge `RECOVER`, wind-down actions (`Prepare for sleep`, `keep the evening calm`) | **intentional new contract** (badge) + **needs product decision** (hydration mention) | Aligns with a7b7d4d calm evening wind-down. Hydration in protect-tomorrow evening may be intentionally de-emphasized when fuel is covered. |
| `testProtectTomorrowStoryBeatsHydrationStory` | Tomorrow-protection story should win over standalone hydration story | Hydration or other story wins | **needs product decision** | Overlaps owner/badge refactor; tomorrow content may still be present under `stableOverview` owner. |
| `testRecoveryActionsRemoveFoodAndHydrationAsTheyAreCompleted` | As user completes food/hydration actions, they drop from action list | Completed actions still shown | **needs product decision** | Action lifecycle policy — may be V5 dynamic-text behavior change. |
| `testSupportSignalsNeverReplacePrimaryActions` | Support signals must not duplicate primary action content | Overlap detected | **stale legacy expectation** | New composed-frame narrative may intentionally echo themes across sections; verify against Phase 3 dedupe rules. |
| `testSupportSignalsRenderForStableNextActivityLater` | Stable next activity + injected support bullets → support renders in UI story | Support not rendering | **real regression** (if injection contract holds) | Same pipeline as `testPrepareRideShowsHydrationSupportWhenWaterZero`. |
| `testHeroAndActionsUseSameDayPhase` | Hero badge `PROTECT TOMORROW` matches close-phase hydration actions | Hero `RECOVER` with wind-down actions | **intentional new contract** | Document badge downgrade; verify tomorrow copy still visible in read/support. |

### CoachStateNarrativeContractTests

| Test | Old contract | Actual behavior | Classification | Notes |
|------|--------------|-----------------|----------------|-------|
| `testUpcomingEnduranceWorkoutTimingOwnsWhileWaterAndFoodSupport` | Primary recommendation mentions fluids/bottle while timing owns hero | Primary is legs/stillness prep copy (`What you feel in your legs… Stillness preserves…`) | **intentional new contract** | Prep catalog reframed; hydration may belong in why/support not primary. Confirm in matrix endurance prep scenarios. |
| `testUpcomingEnduranceWorkoutUsesConcreteHumanPrepStory` | Same fluid/bottle expectation in prep primary | Legs/stillness primary copy | **intentional new contract** | Duplicate of above at different assertion depth. |
| `testV4LongRideIn45MinutesUsesImmediatePreparationWindow` | Prep primary contains hydration-adjacent tokens | Legs/stillness framing | **intentional new contract** | Category A updated endurance band tokens from `fluids` → `legs`/`stillness`. |
| `testStableDayDoesNotShowMildFoodWaterSupportRows` | Stable day primary ≠ generic `"Stay with today's plan"` when mild food/water gaps | Generic stable primary `"Stay with today's plan"` | **intentional new contract** | Phase 3 validates calm stable overview; mild gaps intentionally not elevated. |
| `testV4HighRecoveryLowStrainCanRecommendDoingNothing` | Specific calm strings (`Recovery looks solid…`, explicit doing-nothing recommendation) | Generic stable copy + `"Stay with today's plan"` | **intentional new contract** | Same calm-day template as Phase 3 matrix A1/F1. |
| `testSundayMorningModerateRecoveryNoWorkoutUsesCalmReadinessOverview` | Calm readiness overview without fuel deficit copy | Fuel + short-sleep deficit copy (`Start with fuel…`, `Last night was shorter…`) | **stale legacy expectation** | Scenario uses 6.42h sleep + zero food — test name contradicts inputs. Split scenario or update expectation. |
| `testRussianSaunaHydrationCopySoundsHumanAndKeepsSaunaHero` | Russian sauna prep: sauna hero, hydration in support/why with human phrasing | Copy repetition / phrase mismatch (`попейте воды воды`) | **stale legacy expectation** (Category A pending) | Copy-only refresh needed; sauna hero + hydration support policy unchanged. |

### Matrix scenarios (within `testFullCoachEngineScenarioMatrixEnglish`)

| Scenario | Old contract | Actual behavior | Classification | Notes |
|----------|--------------|-----------------|----------------|-------|
| **A2** morning low water no heat | Useful primary support OR explicit no-action; forbid generic stable primary | Generic stable / `"Stay with today's plan"` | **intentional new contract** | Phase 3 A2 equivalent passes without mandatory hydration row. |
| **B3** workout soon severe hydration | Visible copy contains drink/hydration/water/sip tokens | Prep primary is legs/stillness; fluids may be in why not hero | **needs product decision** | Severe hydration + imminent workout: should drink language be mandatory in visible surface? |
| **G1** mild hydration stable day | Useful support or explicit no-action | Generic stable primary | **intentional new contract** | Mild gap on stable day — align with calm overview policy. |
| **G3** food low morning no workout | Useful support; forbid `"breakfast"` in copy | `"Start with fuel this morning"` / breakfast language present | **intentional new contract** (primary) + **needs product decision** (breakfast word ban) | Engine now proactively surfaces fuel on low-food mornings; matrix forbid-list may be stale. |

### CoachDayPriorityResolverXCTests

| Test | Old contract | Actual behavior | Classification | Notes |
|------|--------------|-----------------|----------------|-------|
| `testActiveWorkoutWithLowFuelAndHydrationStaysLiveGuidance` | Active workout + low fuel/hydration → live guidance priority wins | Different priority winner | **needs product decision** | During-activity fuel/hydration vs live execution owner — overlaps Owner Collapse Review. |

---

## Proposed policy decisions (for product sign-off)

1. **Calm morning, no activity, mild water gap:** Do not surface hydration support (Phase 3 calm contract) vs. always show soft hydration support row.
2. **Prep window, water zero, activity within 2h:** Hydration must appear in support or why (minimum bar) — several failures suggest this regressed.
3. **Severe hydration + workout <60 min away:** Require explicit drink language somewhere in visible story (hero, why, or support).
4. **Evening protect-tomorrow:** Badge `RECOVER` + wind-down actions is acceptable if tomorrow plan copy remains in read/support; hydration mention optional when fuel covered.
5. **Endurance prep primary copy:** Legs/stillness framing replaces fluid-first hero — hydration moves to support/why channel.

---

## Next steps (after sign-off)

1. Fix **real regression** cluster (prep-window support rendering) in engine — not in this review pass.
2. Update **stale legacy** matrix forbid-lists and contradictory scenario tests.
3. Refresh **Category A pending** Russian sauna/run prep golden strings.
4. Document **intentional new contract** in matrix auditor comments so future runs do not re-flag.
