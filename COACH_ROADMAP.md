# Coach V5 Roadmap

> Living status for narrative architecture work.  
> Source of truth for arc design: `COACH_V5_NARRATIVE_ARCHITECTURE.md`

---

## North star

**Arc появляется только тогда, когда течение времени меняет решение тренера.**

Chapters live in the **narrative layer** — not as new `CoachFinalStoryOwner` values.

---

## Shipped

### Endurance Narrative vertical ✅

| Phase | Scope | Commit | Status |
|-------|--------|--------|--------|
| **A** | Coach Hero follows engine narrative owner for activity-bound stories | `f909a15` | ✅ Shipped |
| **B** | Endurance Arc — Opening → Establish → Maintain → Protect → Recovery Window | `fb16d58` | ✅ Shipped |
| **C** | Today teaser reads same chapter model as Coach (tactical, not copied) | ✅ Shipped |

**Activities:** Cycling, Running · duration ≥ 60 min  
**Docs:** `COACH_ENDURANCE_NARRATIVE_ARC.md` · `COACH_PHASE_B_CHAPTER_SCREEN_AUDIT.md`

**Architecture pattern (reuse for future arcs):**

```
Activity Family → Arc Template → Chapter (narrative layer)
    → Copy catalog (Coach Hero / Read / Rec)
    → CoachEnduranceTodayTeaserCopy (Today tactical lines)
    → Owners unchanged (priority + deficit override)
```

---

## In progress

### Endurance screenshot audit (manual)

Before starting Racket Arc implementation, confirm real screens for 4 h ride:

| # | Chapter | Elapsed | Coach Hero (RU) | Today title (RU) |
|---|---------|---------|-----------------|------------------|
| S1 | Opening | 20 min | Войдите в поездку плавно | Сначала легко |
| S2 | Establish | 45 min | Задайте ритм питания | Не пропускайте следующий приём |
| S3 | Maintain | 120 min | Держите ровную середину | Продолжайте по плану |
| S4 | Protect | 210 min | Берегите финиш | Не добавляйте усилие сейчас |
| S5 | Recovery Window | +10 min post | Окно восстановления открыто | Сейчас важнее восстановление |

Checklist: `COACH_PHASE_B_CHAPTER_SCREEN_AUDIT.md` (S1–S5 + read-aloud coherence).

**Gate:** Racket Arc code starts **after** screenshot sign-off.

---

## Next

### Racket Arc (Tennis / Squash)

**Goal:** Court sessions feel like a **separate coach style**, not Endurance Arc with swapped words.

**Constraints (same as Endurance):**

- No new owners
- Same ArcTemplate approach — chapters in narrative layer only
- Today and Coach read **one** chapter model (`CoachRacketNarrativeContextResolver` + shared resolver pattern)
- Hydration / fuel / readiness overrides keep priority over chapter copy

**Designed chapters:**

| Duration | Arc |
|----------|-----|
| 60 min | Warm In → Manage Load → Close Smart |
| 90 min | Warm In → Find Rhythm → Manage Load → Close Smart |
| 120+ min | Warm In → Find Rhythm → Manage Load → Close Smart |

Close Smart: `max(75% elapsed, last 25–30 min)` — shorter final act than endurance.

**Status:** Design approved in `COACH_V5_NARRATIVE_ARCHITECTURE.md` · implementation **blocked on Endurance screenshot audit**.

---

## Planned

| Arc | Activities | Model | Status |
|-----|------------|-------|--------|
| **Heat** | Sauna | 3-phase lifecycle (Prepare → During → Post) | Partial playbook · formalize arc |
| **Strength** | Upper / Lower / Core / Full Body | Flat during + post timing | ✅ Exists |
| **Recovery** | Walk, Yoga, Stretch, Breath | Flat | ✅ Exists |

---

## Explicitly not in scope (this cycle)

- New `CoachFinalStoryOwner` values for narrative chapters
- Universal Opening → Working → Protect → Recovery template for all sports
- ML / feel-based chapter detection
- Large architectural refactors outside arc families

---

## V5 arc inventory (target)

| Family | Arc? | Status |
|--------|------|--------|
| Endurance | 5-chapter arc | ✅ Shipped |
| Racket | 3–4 chapter arc | 📋 Next (after audit) |
| Heat | 3-phase lifecycle | 🔶 Future polish |
| Strength | Flat | ✅ |
| Recovery | Flat | ✅ |

---

*Last updated: Phase C commit — Endurance vertical complete.*
