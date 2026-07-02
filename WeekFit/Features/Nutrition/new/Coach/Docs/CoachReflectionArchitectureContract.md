# Coach Reflection — Architecture Contract

> Status: active  
> Scope: Reflection eligibility, presentation, and boundaries with Guidance

---

## Purpose

Coach Reflection is not a feature surface. It is a **quiet continuation** of the same Coach conversation — spoken only when operational Guidance is complete and Coach's understanding of the athlete has changed.

Reflection communicates **belief change**. It does not report data, summarize weeks, or prescribe action.

---

## Product principles

| Principle | Meaning |
|-----------|---------|
| **Guidance owns the moment** | Preparation, safety, recovery, and tomorrow protection always win. Reflection never delays or replaces operational Guidance. |
| **Reflection owns the pause** | Reflection may speak only when today's important Coach conversation has naturally finished. |
| **Understanding, not time** | Reflection is driven by **understanding events**, never by calendar intervals or "a month has passed." |

---

## Hard constraints (non-negotiable)

| # | Constraint |
|---|------------|
| R1 | **No new scenario keys** for Reflection |
| R2 | **No routing changes** — `CoachScenarioResolver`, `CoachFocusResolver`, and scenario modifiers are unchanged by Reflection |
| R3 | **No fingerprint changes** — Reflection eligibility does not alter `CoachInputFingerprint` or Coordinator recompute cadence |
| R4 | **Pause gating only** — Reflection reads `CoachContext` and `CoachInputSnapshot`; it never writes routing state |
| R5 | **Nil by default** — `CoachState.reflectionOffer` is `nil` unless pause + unspoken understanding event |
| R6 | **UI renders nothing without an offer** — `CoachReflectionContinuationView` produces no layout when `offer == nil` |
| R7 | **No clock triggers** — no scheduled, daily, weekly, or evening-timer Reflection |

---

## Layer placement

```
CoachInputSnapshot
    ↓
CoachEngine / CoachScenarioResolver     ← UNCHANGED (Guidance)
    ↓
CoachTabPresentationBridge              ← UNCHANGED (Guidance UI)
    ↓
CoachState.coachUIPresentation          ← Guidance output

CoachObservationStore                   ← daily evidence (background)
CoachUnderstandingStore                 ← beliefs + understanding events
    ↓
ConversationPauseResolver               ← read-only pause gate
ReflectionComposer                      ← pause + event → ReflectionOffer?
    ↓
CoachState.reflectionOffer              ← optional overlay
CoachReflectionContinuationView         ← renders only when offer exists
```

Guidance and Reflection are **siblings**. Reflection is not downstream of Guidance in routing — only in presentation order inside the Coach card.

---

## When Reflection may speak

All must be true:

1. **Conversational pause** — `ConversationPauseResolver.isPaused == true`
2. **Unspoken understanding event** — a new belief delta exists in `CoachUnderstandingStore`
3. **Not already spoken** — event ID absent from utterance ledger

---

## When Reflection must stay silent

Reflection is blocked while any Guidance owner is active:

| Blocker | Examples |
|---------|----------|
| Active workout | `focusSource == .active`, `sessionPhase == .during` |
| Pre-workout preparation | `sessionPhase == .pre` |
| Immediate post-workout | `sessionPhase == .immediatePost` |
| Tomorrow protection | `sessionPhase == .tomorrowProtection` |
| Meaningful work remaining | upcoming workout later today |
| Elevated urgency | `urgencyLevel >= .protective` |
| Safety alert | non-`none` alert severity or active `safetyAlert` |

Silence is the correct default. Most Coach visits show Guidance only.

---

## Presentation contract

- Reflection appears **inside the existing Coach card**, after Guidance blocks
- No badge, CTA, expand/collapse, or Insights/dashboard language
- Lead-in copy is conversational (e.g. "One thing I've been noticing…"), not hero-label uppercase
- `ReflectionCopy` shapes utterance text; `CoachReflectionPresentation` shapes lead-in only
- Belief inference and eligibility live outside the view layer

---

## What Reflection is not

- Not an Insights tab or Story screen
- Not a second recommendation card
- Not a scenario or CopyPack variant
- Not triggered by evening clock alone (evening may coincide with pause; pause is not defined by time)

---

## Regression surface

Tests that must pass before merge:

- `ReflectionEligibilityRegressionTests` — blocked Guidance owners prevent offers
- `CoachConversationPhaseSafetyTests` — Guidance routing unchanged
- `ConversationPauseResolverTests` — pause gate matrix
- `ReflectionComposerTests` — compose contract
- `CoachReflectionPresentationTests` / `CoachReflectionSnapshotTests` — presentation copy and layout snapshots

---

## Files (reference)

| File | Role |
|------|------|
| `Reflection/ConversationPauseResolver.swift` | Pause gate |
| `Reflection/ReflectionComposer.swift` | Offer composition |
| `Reflection/CoachUnderstandingService.swift` | Observe + evaluate (background) |
| `Presentation/CoachReflectionContinuationView.swift` | UI continuation |
| `Presentation/CoachReflectionPresentation.swift` | Lead-in copy |
| `Core/CoachState.swift` | Optional `reflectionOffer` on ready state |
