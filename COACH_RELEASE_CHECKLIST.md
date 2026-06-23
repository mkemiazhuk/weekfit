# Coach Release Checklist

> **Purpose:** Release gate for Coach — validate guardrails before every App Store / TestFlight ship.  
> **Source:** `COACH_V5_GUARDRAILS.md` · `COACH_GUARDRAIL_TEST_MAPPING.md`  
> **Owner:** QA + author of any Coach-touching PR in the release.

**Release:** ___________  
**Coach PRs in release:** ___________  
**Sign-off:** QA [ ] · Product [ ] · Engineering [ ]

---

## P0 — must pass (block release if any fail)

| Check | Guardrail | How to verify | Pass |
|-------|-----------|---------------|------|
| No duplicate narratives | 2 | Matrix audit + spot-check live/pre screenshots; no hero = support duplicate | [ ] |
| No Today/Coach semantic overlap | 11 | `testTodayAndCoachPresentationIntentSeparationAcrossKeyScenarios` green | [ ] |
| No Steady masking limiter | 3 | Matrix `recoveryNeeded` + low recovery calm cases; manual: recovery low + workout later | [ ] |
| No Adjust/Get Ready inversion | 4 | `testCriticalTrainingReadinessWarningBeatsNormalRunPreparation` · prep-window screenshots | [ ] |
| No live caution without limiter | 6 | `testLivePlannedCyclingWithReadyRecoveryUsesCautionNotRed` · easy walk live screenshots | [ ] |
| No missing live caution when limiter exists | 5, 6 | `testActivePhaseCriticalReadinessOverrideChangesFinalVisibleStory` · matrix `activeSession` cautious | [ ] |
| In Session owns live (Adjust absorbed) | 5 | Live session screenshots: one card, one family | [ ] |

**P0 gate:** All boxes checked. Any unchecked → **stop release**.

---

## P1 — must pass or have documented exception

| Check | Guardrail | How to verify | Pass |
|-------|-----------|---------------|------|
| Wind Down names a stake | 9, 13 | Evening screenshots with hard tomorrow; no generic “sleep more” | [ ] |
| Recover follows meaningful load | 8 | Post-hard screenshots → Recover; light walk → not Recover hero | [ ] |
| Nutrition remains tone-only | 10 | No nutrition-led hero without prep/recover/wind-down frame | [ ] |
| Adjust copy distinct from Steady/Get Ready | 7 | Adjust screenshots: clear plan change, not calm/prep | [ ] |
| One leading family | 1 | Random 10-scenario screenshot batch | [ ] |
| Stake explained on behavior-change copy | 13 | Coach tab shows *why* for Adjust / cautious / Recover / Wind Down | [ ] |

**P1 gate:** All checked or exception logged in release notes with rule number.

---

## P2 — spot-check (heat / modality)

| Check | Guardrail | How to verify | Pass |
|-------|-----------|---------------|------|
| Heat remains recovery-focused | 12 | Sauna pre/during/post screenshots — safety, not pace | [ ] |

---

## Automated test gate

Run before sign-off:

```bash
xcodebuild test -scheme WeekFit \
  -only-testing:WeekFitTests/CoachDayPriorityResolverXCTests \
  -only-testing:WeekFitTests/CoachStateNarrativeContractTests \
  -only-testing:WeekFitTests/HumanCoachDecisionEngineXCTests \
  -only-testing:WeekFitTests/TodayCoachContradictionRegressionTests
```

**Matrix audit** (required if any narrative/copy PR in release):

```bash
xcodebuild test -scheme WeekFit \
  -only-testing:WeekFitTests/CoachNarrativeMatrixValidationSuite
```

| Suite | Pass |
|-------|------|
| Priority resolver | [ ] |
| Narrative contract | [ ] |
| Human coach scenarios | [ ] |
| Contradiction regression | [ ] |
| Matrix validation (if required) | [ ] |

---

## Screenshot batch (minimum)

| # | Scenario | Today + Coach captured | Screenshot review PASS |
|---|----------|------------------------|------------------------|
| 1 | Calm morning, no workout | [ ] | [ ] |
| 2 | Prep window, good recovery | [ ] | [ ] |
| 3 | Prep window, **low recovery** | [ ] | [ ] |
| 4 | **Live** normal execution | [ ] | [ ] |
| 5 | **Live** with limiter | [ ] | [ ] |
| 6 | Post-hard workout (<90 min) | [ ] | [ ] |
| 7 | Evening, **hard tomorrow** | [ ] | [ ] |
| 8 | Sauna planned (if heat in release) | [ ] | [ ] |

Use `COACH_SCREENSHOT_REVIEW_CHECKLIST.md` for each row.

---

## Telemetry sanity (if instrumented)

| Metric | Expected | Actual | OK |
|--------|----------|--------|-----|
| `steady_day` lead rate | 40–55% | | [ ] |
| `adjust` lead rate | 4–8% | | [ ] |
| `in_session` lead rate | 5–12% | | [ ] |
| Coach mute rate vs prior release | Not spiking | | [ ] |

*See `COACH_V5_FREQUENCY_MODEL.md` validation checklist.*

---

## Release decision

| | |
|---|---|
| **P0** | [ ] All pass |
| **P1** | [ ] All pass or exceptions documented |
| **Tests** | [ ] Green |
| **Screenshots** | [ ] Batch reviewed |

**Release Coach:** [ ] **GO** · [ ] **NO-GO**

**Exceptions / notes:**

---

*Concise gate. Full rules: `COACH_V5_GUARDRAILS.md`. Test gaps: `COACH_GUARDRAIL_TEST_MAPPING.md`.*
