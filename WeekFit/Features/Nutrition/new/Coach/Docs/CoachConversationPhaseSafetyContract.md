# CoachConversationPhase — Safety Contract (V1)

> Status: pre-implementation gate  
> Scope: V1 only — tone/presentation policy layer, **not** scenario routing

---

## Purpose

`CoachConversationPhase` answers one question for idle/low-urgency moments:

**«Какой разговорный тон уместен прямо сейчас — steady, opening, или closing?»**

It must **never** become a parallel decision engine for Coach stories, activity focus, or scenario keys.

---

## Hard constraints (non-negotiable)

| # | Constraint |
|---|------------|
| C1 | **No new scenario keys** |
| C2 | **No new router** (no `InteractionScenarioRouter`, no conversation routing in `CoachScenarioResolver`) |
| C3 | **No change to owner selection** (`CoachFocusResolver`, focus chain, priority stack) |
| C4 | **No change to activity routing** (`CoachScenarioResolver` primary paths for endurance/racket/strength/recovery/heat) |
| C5 | **No change to V5 fallback** (registry gap / settling behavior unchanged) |
| C6 | **No UI changes** (views, presentation structs, bridge output shape) |
| C7 | **No CopyPack bridge structure changes** (`CoachTabPresentationBridge` API and mapping unchanged in PR1) |
| C8 | **No TTL, afterUserAction, afterFreshData, or trigger taxonomy in V1** |
| C9 | **No `CoachInputFingerprint` changes in PR1** — fingerprint equality and recompute/cache behavior must stay identical |

---

## Allowed responsibilities (V1)

ConversationPhase **may only**:

1. **Compute** one of three values: `.steady`, `.dayOpening`, `.dayClosing`
2. **Log** the selected phase and the reason (debug / trace only in PR1)
3. *(PR2+)* Shape copy **tone** for idle/evening states — overlays on existing packs, not new scenarios
4. *(PR2+)* Reduce inappropriate deficit/catch-up **urgency** from nutrition/hydration during opening/closing windows (presentation policy + supporting-signal suppression)

ConversationPhase **must not** in V1:

- Select or override `CoachScenarioKey`
- Replace `CoachDayReadinessRouter` outcomes
- Change `CoachFocusSelection` or `sessionPhase`
- Add fields to `CoachScenarioModifiers` that affect scenario selection
- Introduce new recompute triggers beyond existing refresh paths

---

## Layer placement

```
CoachInputSnapshot
    ↓
CoachEngine.buildContext
    → CoachContext (+ conversationPhase, read-only)
    ↓
CoachScenarioResolver          ← UNCHANGED routing (PR1)
CoachPresentationResolver      ← UNCHANGED (PR1); policy hook in PR2 only
CoachCopyRegistry              ← UNCHANGED (PR1); tone shaping in PR2 only
CoachTabPresentationBridge     ← UNCHANGED
```

`conversationPhase` is **attached context**, not a routing input, until PR2 explicitly enables tone/urgency shaping behind feature-safe guards.

In PR1 it lives on **`CoachContext` only** (computed in `CoachEngine.buildContext`). It is **not** stored on `CoachInputSnapshot` unless a compile-time requirement forces a passthrough — and even then it must not feed fingerprint or coordinator skip logic.

---

## CoachInputFingerprint (PR1)

**Do not add `conversationPhase` to `CoachInputFingerprint` in PR1.**

Reason: fingerprint drives `CoachCoordinator.recomputeIfNeeded` skip/evaluate decisions. Any new fingerprint field can change when Coach refreshes — that violates zero-behavior-change even if copy is unchanged.

| PR | Fingerprint |
|----|-------------|
| **PR1** | **Unchanged.** Same `rawValue` for the same snapshot inputs as before. |
| **PR2 / PR3** | Changes allowed **only** when tone/urgency shaping is intentionally enabled, documented, and covered by tests that assert desired recompute behavior. |

PR1 must:

- compute `conversationPhase`
- attach it to `CoachContext` as read-only debug/context
- log phase + reason
- add safety tests
- **keep fingerprint equality unchanged**

First-open tracking (if needed for `.dayOpening`) uses **separate session state** (e.g. `CoachSessionTracker`) that does **not** participate in `CoachInputFingerprint` until a later PR explicitly opts in.

---

## Phase definitions (V1)

| Phase | Meaning |
|-------|---------|
| **steady** | Default. Current Coach behavior. |
| **dayOpening** | First meaningful Coach interaction today in morning/wake window; zero metrics are expected, not deficits. |
| **dayClosing** | Late evening, no meaningful activities remaining; wind-down frame, not catch-up. |

If conditions are ambiguous or conflict with activity/safety owners → **steady**.

---

## Priority rule (safety)

ConversationPhase is **subordinate** to all activity and safety owners:

```
safetyAlert / stackedDayActiveRisk
    > active session (during)
    > imminent pre-session (≤ 45–60 min)
    > immediate post-workout
    > tomorrowProtection / lowRecoveryPrep / recoveryAfterHeavyYesterday
    > idle day stories (morningReadiness, stableDay, …)
    > conversationPhase tone/urgency shaping (PR2+ only)
```

When any higher-priority owner applies, conversationPhase must remain computed (for logs) but **must not alter** scenario, owner, or safety presentation.

---

## PR1 acceptance criteria

- [ ] **Zero visible behavior change** — Today card and Coach screen identical to pre-PR1 for all existing tests
- [ ] **All existing Coach tests pass** without scenario/assertion updates (except new contract tests)
- [ ] **Phase appears only in logs/debug** — e.g. `[CoachConversationPhase] phase=steady reason=…`
- [ ] **`CoachInputFingerprint` unchanged** — same inputs → same `rawValue`; `skippedUnchangedCount` / recompute timing unchanged
- [ ] **No new branches in `CoachScenarioResolver`** except forwarding `conversationPhase` on context if struct requires it (no `switch conversationPhase` routing)
- [ ] **No new scenario keys, routers, UI, bridge, or trigger types**

---

## Regression tests (required)

New suite: `CoachConversationPhaseSafetyTests` (or sections in existing suites).

Each test must assert: **given high-priority owner, conversationPhase computation does not change scenario, focus, or safety outputs.**

### Must NOT be affected by conversationPhase (PR1)

| Case | Assert unchanged |
|------|------------------|
| Active workout | scenario = `during*`, focus = active, safety alerts fire if critical |
| During workout | `alertSeverity` critical when `safetyAlert` present |
| Imminent pre-session (≤ 45–60 min) | scenario = `active*` or `lowRecoveryPrep`, not idle opening |
| Immediate post-workout | scenario = `post*Immediate`, sessionPhase = immediatePost |
| tomorrowProtection | scenario = `tomorrowProtection`, protection story wins over closing |
| lowRecoveryPrep | scenario = `lowRecoveryPrep` when pre-session + low recovery |
| Safety-critical hydration/fuel | `safetyAlert` + warning layer during `duringEndurance` |
| stableDay routing | same scenario key as baseline without conversation enabled |
| morningReadiness routing | same scenario key as baseline without conversation enabled |

### PR1-specific assertions

- `CoachEngine.evaluate` result **equals** baseline when conversationPhase is injected as `.dayOpening` / `.dayClosing` but **PR2 policy is disabled** (or not wired)
- `CoachScenarioResolver.resolve(context)` output identical with and without `conversationPhase` on context
- `CoachTabPresentationBridge.build` output identical PR1 before/after
- `CoachInputFingerprint(snapshot:)` **identical** before/after PR1 for representative snapshots (including first-open session state where phase logs `.dayOpening` but fingerprint does not change)

### PR2 gate (future — not in PR1)

Before enabling tone/urgency shaping:

- [ ] Opening/closing only affect copy/severity when `sessionPhase == .idle` (or explicit evening post-session allowlist)
- [ ] `safetyAlert != nil` → severity unchanged
- [ ] `stackedDayActiveRisk` → severity unchanged
- [ ] Existing `CoachScenarioTests` G1 guard still passes

---

## Explicit non-goals (V1)

- Conversation-trigger enum or source taxonomy
- Session TTL / decay for post-action moments
- Post-sync / post-meal-log conversation frames
- New teaser titles in `CoachTabPresentationBridge` (PR2 optional, not required for contract)
- **`CoachInputFingerprint` changes in PR1** (deferred to PR2/PR3 when shaping is enabled and recompute impact is tested)

---

## Review checklist (before merge)

1. Grep: no `switch conversationPhase` inside `CoachScenarioResolver`
2. Grep: no new `CoachScenarioKey` cases
3. Grep: no `InteractionRouter` / `ConversationRouter` types
4. Grep / diff: **`CoachInputFingerprint.swift` unchanged in PR1** (or no new conversation-related fingerprint segments)
5. Full Coach test suite green
6. Manual: Today + Coach UI unchanged on smoke pass
7. Logs show phase + reason on recompute
8. `CoachCoordinator.skippedUnchangedCount` behavior unchanged for repeated identical snapshots

---

## Related docs

- `CoachScenarioMatrix.md` — scenario guard rules G1–G5
- `CoachEdgeCaseMatrix.md` — ownership priority stack
