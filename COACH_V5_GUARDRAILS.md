# Coach V5 Guardrails

> **Non-negotiable rules** for product, engineering, QA, and design.  
> **Source:** `COACH_V5_TRUST_MODEL.md` · `COACH_V5_FAILURE_MODEL.md`  
> **Scope:** Seven V5 families · Today + Coach surfaces · nutrition tones

If a change violates any rule below, it does not ship until resolved or the rule is explicitly revised.

---

### 1. One leading family at a time

**Why:** Users decide in one glance whether Coach is worth listening to. Split attention kills decision trust.  
**Trust if broken:** Medium → High — “Coach is noisy / I don’t know what matters.”  
**Example:** Hard session in 30 min with low recovery → **Adjust** only. Not Adjust on Coach tab and Get Ready on Today.

---

### 2. Duplicate narratives are P0 defects

**Why:** During load, cognitive overhead is highest. Two cards = both get ignored.  
**Trust if broken:** High — especially live; user mutes Coach.  
**Example:** “Ease up now” on Today **and** “Reduce ride intensity” on Coach while session is live → **one** In Session · cautious story.

---

### 3. Steady Day must never mask a real limiter

**Why:** Steady is ~half of impressions (habit trust). False calm is the #5 failure to prevent.  
**Trust if broken:** High → **Catastrophic** — “Coach doesn’t see my body.”  
**Example:** Recovery 55%, long run in 2 h → **not** “Nothing needs fixing.” Route to Adjust or Get Ready with escalation.

---

### 4. Adjust beats Get Ready when readiness is poor

**Why:** Prep copy says “go”; Adjust says “change the plan.” Wrong family = user enters depleted.  
**Trust if broken:** **Catastrophic** — bad session, injury risk, “Coach is useless.”  
**Example:** Strength in 45 min, sleep 4 h → **Adjust · prep reduction**, not “Prepare for the start.”

---

### 5. In Session absorbs Adjust when live

**Why:** Product rule: Adjust pre-start, In Session mid-effort. Same truth, one live owner.  
**Trust if broken:** **Catastrophic** — contradictory or missing live cue.  
**Example:** Critical readiness **during** ride → In Session · cautious (“Ease up now”), not a separate Adjust card.

---

### 6. Live “ease up” requires an active limiter

**Why:** #3 trust failure — caution when user feels fine destroys live credibility permanently.  
**Trust if broken:** **Catastrophic** — “I ignore Coach when it counts.”  
**Example:** Good recovery, easy walk live → In Session · steady. **No** red “This is not the day to push.”

---

### 7. Adjust must not rhyme with Steady or Get Ready

**Why:** Adjust is rare; if it sounds like calm or prep, users won’t change the plan.  
**Trust if broken:** High — future real Adjust calls dismissed as “conservative noise.”  
**Example:** **Bad:** “Manage intensity” on a green Steady-feeling card. **Good:** “Reduce today’s ride — recovery isn’t there” + clear alternative.

---

### 8. Recover must follow meaningful load

**Why:** Post-hard window (~90 min) is when users decide whether Coach respects their effort.  
**Trust if broken:** High — “Coach doesn’t care what I just did.”  
**Example:** After long ride → **Recover** (“Absorb the work”), not Steady or Get Ready for tomorrow’s session yet.

---

### 9. Wind Down requires a named stake

**Why:** Generic “sleep more” feels preachy; named stake earns evening restraint.  
**Trust if broken:** Medium → High — “Coach moralizes at night.”  
**Example:** **Bad:** “Wind down tonight.” **Good:** “Protect tomorrow’s long run — keep the evening easy.”

---

### 10. Nutrition is a tone — cannot lead unless severe

**Why:** Eat/drink on ~25–35% of moments; standalone nutrition family was <2% of days and erodes calm.  
**Trust if broken:** Medium → High — “Coach is a food app” / breaks Steady promise.  
**Example:** Under-fueled before run in 45 min → Get Ready · nutrition tone. Severe orphan gap only → Steady · urgent (rare).

---

### 11. Today and Coach cannot tell the same story

**Why:** Today = tactical (idea + action, ≤44/88 chars). Coach = interpretive (why + context). Same copy on both wastes a surface.  
**Trust if broken:** Medium — “Product is redundant / broken.”  
**Example:** Today: “Ease up now · Keep the next block lighter.” Coach: “Recovery is limiting today — reserve matters more than pace.”

---

### 12. Heat is recovery, not training

**Why:** Heat users trust Coach on safety; athletic framing in sauna causes dehydration and modality confusion.  
**Trust if broken:** High (heat users) · Low (others).  
**Example:** Sauna planned → Heat & Sauna · safety (“Hydrate first, keep it moderate”), not endurance pacing or “push” language.

---

### 13. Coach must explain the stake

**Why:** Advice without a reason feels arbitrary. Users trust recommendations they understand.  
**Trust if broken:** Medium → High — “Coach is bossy / random.”  
**Example:** **Bad:** “Ease up now.” **Better:** “Recovery is limiting today — ease up now.” **Bad:** “Protect tomorrow.” **Better:** “Tomorrow’s long ride matters more than squeezing more out of tonight.”

**Rule:** Whenever Coach asks the user to change behavior (Adjust, In Session caution, Recover, Wind Down), name the stake whenever space allows. Users follow advice more often when they understand what is being protected. On Today, action can lead; Coach tab carries the why (see rule 11).

---

## Priority at a glance

| Tier | Rules | Owner |
|------|-------|-------|
| **P0 — never break** | 2, 3, 4, 5, 6 | Engineering + QA |
| **P1 — ship only with review** | 1, 7, 8, 9, 11, 13 | Product + Design + Copy |
| **P2 — modality & tone** | 10, 12 | Product + Copy |

**Regression focus:** Matrix groups `workoutPrep` (low recovery), `activeSession` (cautious + normal), `postWorkout`, `eveningWindDown`.

---

*One page. No exceptions without updating this doc.*
