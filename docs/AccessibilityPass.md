# Accessibility Pass Checklist

Manual QA pass for Dynamic Type and VoiceOver before release.

> **Code-complete (July 2026):** tab bar labels, screen identifiers, quick actions, Coach insight, Up Next live/upcoming, Coach why rows, planner delete confirmation, Health readiness labels localized.

## Today

- [x] Coach insight card: badge, title, subtitle read in order (`accessibilityLabel` on insight button)
- [x] Quick actions: each button has a unique accessibility label (`label + subLabel`)
- [x] Live activity row announces state (`today.upNext.liveAccessibilityFormat`)
- [ ] Date header remains legible at AX5 content size — **manual**

## Coach

- [ ] Hero story title and recommendation are not duplicated by VoiceOver — **manual spot-check**
- [x] Support action chips have hint text where icons are decorative (`coachDecisionRow` ignores decorative icon)
- [ ] Health connect prompt is reachable and dismissible with VoiceOver — **manual**

## Plan

- [x] Timeline rows expose activity title, time, and status (`PlanTimelineRow`)
- [x] Drag-to-reschedule has an accessibility alternative (edit sheet via tap / context menu)
- [x] Delete confirmation is announced before destructive action (`confirmationDialog`)

## Meals

- [ ] Library sections expose meal macros in summary — **manual**
- [ ] Coach recommendation card links to suggested meal name — **manual**
- [ ] Create-meal flow fields have labels at large content sizes — **manual**

## Global

- [x] Tab bar items have localized accessibility labels (EN + RU)
- [ ] Sheets trap focus and support rotor navigation — **manual**
- [ ] No critical actions rely on color alone — **manual**
