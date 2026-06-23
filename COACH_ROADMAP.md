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

## Manual QA (optional)

### Endurance screenshot audit

Confirm real screens for 4 h ride (S1–S5): `COACH_PHASE_B_CHAPTER_SCREEN_AUDIT.md`

### Racket Narrative vertical ✅ (Phase D)

| Phase | Scope | Status |
|-------|--------|--------|
| **D** | Racket Arc — Warm In → Find Rhythm → Manage Load → Close Smart → Recovery Window | ✅ Shipped |

**Activities:** Tennis, Squash · duration ≥ 60 min  
**Code:** `CoachRacketSessionChapter` · `CoachRacketDuringPostCopyCatalog` · `CoachRacketTodayTeaserCopy`

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
| Racket | 3–4 chapter arc | ✅ Shipped |
| Heat | 3-phase lifecycle | 🔶 Future polish |
| Strength | Flat | ✅ |
| Recovery | Flat | ✅ |

---

*Last updated: Phase D — Racket Arc shipped.*
