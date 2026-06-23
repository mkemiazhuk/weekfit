# Phase B Chapter Screenshot Audit

> After commit `fb16d58` — endurance session chapters in narrative layer only.  
> Locale: Russian · Simulation + manual screenshot checklist · 2026-06-23

## Method

Compare **Coach Hero** (`CoachFinalStory.title`) and **Today title** (`CoachTabPresentationResolver.resolveToday`) at fixed elapsed points on a long cycling ride.

| Field | Meaning |
|-------|---------|
| **Chapter** | `CoachEnduranceSessionChapterResolver` (Opening → … → Recovery Window) |
| **Coach Hero** | Engine + Coach tab (Phase A contract: must match when activity-bound) |
| **Today title** | Compressed teaser — **chapter-aligned since Phase C** (same family, shorter voice) |

**Pass criteria (Phase B audit):**

1. Five chapters show **distinct Coach Heroes** on a 4 h ride (no deficit).
2. Arc reads as **one developing story**, not template rotation.
3. **Maintain is not eternal** on 4–5 h rides — bounded window before Protect.
4. Deficit still overrides chapter (fuel / hydration).
5. Today matches chapter family (Phase C) — automated + screenshot confirm.

---

## Phase C — Today teaser alignment (4 h ride)

Same simulation as above. **Today title** (idea) must differ across chapters; **Coach Hero** stays interpretive (longer).

| # | Chapter | Elapsed | Coach Hero | Today title (expected) | Today action (expected) |
|---|---------|---------|------------|--------------------------|-------------------------|
| 1 | Opening | 20 min | Войдите в поездку плавно | **Сначала легко** | Добавляйте усилие, когда дыхание успокоится. |
| 2 | Establish | 45 min | Задайте ритм питания | **Не пропускайте следующий приём** | Следующий перекус держите по графику. |
| 3 | Maintain | 120 min | Держите ровную середину | **Продолжайте по плану** | Темп ровный — без рывков. |
| 4 | Protect | 210 min | Берегите финиш | **Не добавляйте усилие сейчас** | Дожмите до финиша спокойно. |
| 5 | Recovery Window | +10 min post | Окно восстановления открыто | **Сейчас важнее восстановление** | Белок и углеводы в ближайший час. |

**Deficit override (during ride):**

| Owner | Today title |
|-------|-------------|
| `fuelingDuringActivity` | **Подкрепитесь сейчас** |
| `hydrationExecution` | **Пора пополнить воду** |

Automated contracts:

- `testFourHourRideTodayTeaserEvolutionAcrossSessionChapters` — rows 1, 3, 4 distinct titles @ 20 / 120 / 210 min
- `testFuelingDeficitOverridesEnduranceTodayChapterTeaser`
- `testFourHourRideHeroEvolutionAcrossSessionChapters` — Coach rows 1–4

---

## Chapter Heroes (RU · cycling)

| Chapter | Coach Hero | Primary action (RU) |
|---------|------------|---------------------|
| Opening | Войдите в поездку плавно | Следующие 10 минут держите легко |
| Establish | Задайте ритм питания | Углеводы каждые 20–30 минут |
| Maintain | Держите ровную середину | Углеводы каждые 20–30 минут |
| Protect | Берегите финиш | Держите текущее усилие |
| Recovery Window | Окно восстановления открыто | 25–40 г белка и 60–100 г углеводов |

Deficit override (any chapter):

| Owner | Hero |
|-------|------|
| `fuelingDuringActivity` | Подкрепитесь сейчас |
| `hydrationExecution` | Пейте по графику |

---

## Maintain window analysis (main question)

Protect starts at `elapsed ≥ max(0.75 × duration, duration − 60)`.

| Planned duration | Opening | Establish | Maintain | Protect | Maintain share |
|------------------|---------|-----------|----------|---------|----------------|
| **90 min** | 0–15 (16 m) | 16–44 (29 m) | 45–66 (22 m) | 67–90 (24 m) | **24%** of ride |
| **2 h (120 m)** | 0–20 (21 m) | 21–59 (39 m) | 60–89 (30 m) | 90–120 (31 m) | **25%** |
| **4 h (240 m)** | 0–20 (21 m) | 21–59 (39 m) | 60–179 (120 m) | 180–240 (61 m) | **50%** |
| **5 h (300 m)** | 0–20 (21 m) | 21–59 (39 m) | 60–239 (180 m) | 240–300 (61 m) | **60%** |

**Reading:** Maintain is the **longest single chapter** on 4–5 h rides, but it is **not infinite** — it ends exactly when Protect begins (last hour on long rides, or last 30 min on a 2 h ride). Opening + Establish + Protect still bookend the story.

**Risk to watch in screenshots:** 4–5 h Maintain may *feel* flat if user opens the app only in the 60–179 min window. Mitigation already in copy: Establish sets fuel rhythm; Protect changes tone sharply at 75%/last hour.

---

## Simulated 4 h ride — five screenshot moments

Activity: `Long ride` · cycling · 240 min · `source=today` · well-fueled nutrition.

| # | Chapter | Elapsed | Remaining | Coach Hero (expected) | Today title (expected) |
|---|---------|---------|-----------|------------------------|------------------------|
| 1 | Opening | 20 min | 220 min | **Войдите в поездку плавно** | **Сначала легко** |
| 2 | Establish | 45 min | 195 min | **Задайте ритм питания** | **Не пропускайте следующий приём** |
| 3 | Maintain | 120 min | 120 min | **Держите ровную середину** | **Продолжайте по плану** |
| 4 | Protect | 210 min | 30 min | **Берегите финиш** | **Не добавляйте усилие сейчас** |
| 5 | Recovery Window | +10 min post | — | **Окно восстановления открыто** | **Сейчас важнее восстановление** |

Automated contract: `testFourHourRideHeroEvolutionAcrossSessionChapters` covers Coach rows 1–4; `testFourHourRideTodayTeaserEvolutionAcrossSessionChapters` covers Today rows 1, 3, 4.

---

## Duration sweep — sample elapsed per chapter

Use the same activity title/type; adjust `durationMinutes` and `minutesFromNow`.

### 90 min ride

| Chapter | Set elapsed | Expected Hero |
|---------|-------------|---------------|
| Opening | 10 min | Войдите в поездку плавно |
| Establish | 30 min | Задайте ритм питания |
| Maintain | 55 min | Держите ровную середину |
| Protect | 75 min | Берегите финиш |

### 2 h ride

| Chapter | Set elapsed | Expected Hero |
|---------|-------------|---------------|
| Opening | 15 min | Войдите в поездку плавно |
| Establish | 40 min | Задайте ритм питания |
| Maintain | 75 min | Держите ровную середину |
| Protect | 105 min | Берегите финиш |

### 5 h ride

| Chapter | Set elapsed | Expected Hero |
|---------|-------------|---------------|
| Opening | 15 min | Войдите в поездку плавно |
| Establish | 45 min | Задайте ритм питания |
| Maintain | 150 min | Держите ровную середину |
| Protect | 270 min | Берегите финиш |

---

## Manual screenshot checklist

For each row, capture **Today tab** + **Coach tab** side by side.

- [ ] **S1 Opening** — 4 h ride @ 20 min elapsed  
- [ ] **S2 Establish** — 4 h ride @ 45 min  
- [ ] **S3 Maintain** — 4 h ride @ 120 min  
- [ ] **S4 Protect** — 4 h ride @ 210 min (30 min left)  
- [ ] **S5 Recovery Window** — 4 h ride completed +10 min  

**Duration spot-check (Coach Hero only):**

- [ ] 90 min @ 55 min → Maintain hero  
- [ ] 2 h @ 105 min → Protect hero (not Maintain — Protect at 90 min)  
- [ ] 5 h @ 150 min → Maintain hero  
- [ ] 5 h @ 270 min → Protect hero  

**Deficit override:**

- [ ] 4 h @ 90 min, low carbs → «Подкрепитесь сейчас», not «середин»  

**Story coherence question (human read-aloud):**

> When scrolling S1→S5, does it sound like one coach following the same ride?

| Check | Pass? |
|-------|-------|
| Opening → Establish feels like “start → settle into fuel rhythm” | |
| Establish → Maintain feels like continuation, not reset | |
| Maintain → Protect feels like “finish discipline”, not new topic | |
| Protect → Recovery feels like closure, not alarm | |
| No chapter repeats the exact same Hero as prior chapter | |

---

## Known gaps (next steps)

| Item | Status |
|------|--------|
| Coach ↔ Engine Hero alignment (Phase A) | ✅ unchanged |
| Chapter evolution (Phase B) | ✅ shipped `fb16d58` |
| **Today teaser chapter alignment (Phase C)** | ✅ chapter-aware via shared resolver |
| Short post-workout Hero polish | ⏸ after Today teaser |

---

## Verdict (pre-screenshot)

| Criterion | Engine simulation | Needs screenshot |
|-----------|-------------------|------------------|
| Distinct Heroes on 4 h arc | ✅ tests pass | confirm UI |
| One developing story | ✅ copy arc designed | read-aloud S1–S5 |
| Maintain not eternal | ✅ bounded (see table) | feel at 120 min elapsed |
| Deficit overrides chapter | ✅ test passes | optional S6 |
| Today matches chapter family | ✅ automated | confirm S1–S5 screenshots |

**Proceed to manual S1–S5 screenshot sign-off, then post-workout Hero polish.**
