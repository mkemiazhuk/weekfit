# Coach Screenshot Review Checklist

> **Purpose:** Review Coach screenshots against guardrails — not subjective taste.  
> **Source:** `COACH_V5_GUARDRAILS.md`  
> **When:** Design review, QA, PR screenshots, App Store captures, localization check.

---

## How to use

1. Capture **Today** (teaser) and **Coach** tab for the same moment.  
2. Answer the 8 questions below.  
3. Record **PASS** · **WARNING** · **FAIL** and violated rule numbers.

---

## Review header

| Field | Value |
|-------|-------|
| Scenario | |
| Time / context | |
| Locale | |
| Reviewer | |
| Date | |

**Screenshots:** Today · Coach · *(optional: live session)*

---

## Eight questions

| # | Question | Answer |
|---|----------|--------|
| 1 | **What family is leading?** | Steady · Get Ready · Adjust · Recover · In Session · Wind Down · Heat |
| 2 | **Is there only one family?** | Yes / No — if No → **Rule 1, 2** |
| 3 | **Does Today tell a different story than Coach?** | Yes / No — Today = action · Coach = why. If same → **Rule 11** |
| 4 | **Is the stake obvious?** | Yes / No / N/A — required for Adjust, In Session caution, Recover post-hard, Wind Down → **Rule 13, 9** |
| 5 | **Is the recommendation actionable?** | Yes / No — user knows what to do next |
| 6 | **Is any limiter being masked?** | Yes / No — calm copy while recovery low, post-hard, or prep imminent → **Rule 3** |
| 7 | **Is there duplicate narrative?** | Yes / No — same headline on both surfaces, or two cards → **Rule 2** |
| 8 | **Would a real coach say this?** | Yes / No — human, proportional, not nagging or generic |

---

## Guardrail spot-checks (by leading family)

| If leading… | Also verify |
|-------------|-------------|
| **Adjust** | Not prep copy (Rule 4, 7) · stake named (13) · clear alternative |
| **Get Ready** | Not Adjust unless readiness clearly good (4) · nutrition sub-tone only (10) |
| **In Session** | LIVE badge · ease-up only if limiter visible (6) · no second Adjust card (5) |
| **Recover** | Follows real load, not light walk (8) · not Steady immediately after hard work (3) |
| **Wind Down** | Named tomorrow stake (9, 13) · not generic sleep lecture |
| **Steady Day** | No hidden urgency · no urgent nutrition (10) · no limiter masked (3) |
| **Heat & Sauna** | Safety language, not training pace (12) |

---

## Verdict

**Result:** [ ] PASS · [ ] WARNING · [ ] FAIL

**Violated rules:** *(numbers only, e.g. 2, 3, 11)*

**Notes:**

---

## Verdict definitions

| Result | Meaning | Action |
|--------|---------|--------|
| **PASS** | All 8 questions OK · no P0 rule violations | Ship |
| **WARNING** | P1 issue (vague stake, weak action, borderline copy) | Fix or document exception before release |
| **FAIL** | Any P0 violation (duplicate narrative, masked limiter, Adjust/Get Ready inversion, live ease-up without limiter) | Do not ship |

---

## Common FAIL patterns (quick reference)

| What you see | Rules |
|--------------|-------|
| “Nothing needs fixing” + low recovery + workout soon | 3, 4 |
| “Prepare for the start” + poor sleep / low recovery | 4, 7 |
| Red “Ease up” on easy walk, user looks fine | 6 |
| Same title on Today and Coach | 11, 2 |
| “Eat more” as main story, no session context | 10 |
| “Wind down tonight” with no tomorrow named | 9, 13 |
| Sauna with pace/effort coaching | 12 |
| “Ease up now” with no reason on Coach tab | 13 |

---

## Batch review (matrix scenarios)

For regression batches, log one row per scenario:

| Scenario | Family | Verdict | Rules | Notes |
|----------|--------|---------|-------|-------|
| | | | | |

Target: **100% PASS** on P0 matrix groups (`workoutPrep` low recovery, `activeSession`, `postWorkout`, `eveningWindDown`).

---

*Subjective polish is optional. Guardrail FAIL is not.*
