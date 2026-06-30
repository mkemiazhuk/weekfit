# Coach Conversation Correctness Audit

> **Цель:** проверить, говорит ли Coach уместные вещи *в конкретный момент времени*, а не только правильно ли выбран сценарий.  
> **Дата:** 2026-06-30  
> **Статус:** аудит (без имплементации)

---

## Executive summary

**Сценарий выбирается в основном правильно.** Разрыв — в *presentation layer*: copy часто звучит как вечерний wind-down в 10:47, потому что:

1. Фразы «остаток дня», «на сегодня достаточно», «день позади» не привязаны к **оставшемуся времени дня**, а к факту завершённой активности.
2. `CoachCopyNutritionTiming.isWindDown` начинается только с **21:00** — между 10:00 и 20:59 вечерняя лексика допустима без guard.
3. `CoachConversationPhase` имеет только 3 значения (steady / morningOverview / dayClosing) — нет Midday / Afternoon / Evening presentation frames.
4. Post-activity copy не проверяет **есть ли ещё активности сегодня**.
5. Nutrition timing не учитывает **intermittent fasting** (есть только в legacy `CoachCopy.swift`).

**Главный риск для пользователя:** после одной утренней прогулки в 10:47 Coach может сказать «день можно завершить» / «остаток дня спокойный» — хотя впереди ещё 12 часов и, возможно, тренировка.

---

## 1. Матрица Conversation Phases

### 1.1 Целевая модель (из ТЗ)

| Phase | Часы | Ожидание тона |
|-------|------|---------------|
| Morning Opening | 06–10 | Сон, восстановление, план дня, ближайшее событие |
| Morning | 10–12 | День только начался; без «завершения» |
| Midday | 12–16 | Середина дня; present + future |
| Afternoon | 16–18 | Можно говорить о вечере как о горизонте, не как о факте |
| Evening | 18–21 | Завершение работы дня, защита сна |
| Wind Down | 21+ | «На сегодня достаточно», сон, ритуал |

### 1.2 Текущая модель в коде

#### `CoachTimeOfDay` (`CoachContext.swift`)

| Bucket | Часы |
|--------|------|
| morning | 5–9 |
| midday | 10–13 |
| afternoon | 14–17 |
| evening | 18–20 |
| lateEvening | 21–22 |
| night | остальное |

**Расхождение с ТЗ:** 10:47 → `midday`, не Morning. Утро заканчивается в 10:00, не в 12:00.

#### `CoachConversationPhase` (presentation frame)

| Phase | Когда | Что меняет |
|-------|-------|------------|
| `.morningOverview` | Первое открытие + morning window (5–9 или 9:00–9:30) | Подавляет nutrition; morning brief Why rows |
| `.dayClosing` | ≥20:30 + нет meaningful work ahead + idle/settledPost | Overlay `CoachDayClosingCopyPolicy` |
| `.steady` | Всё остальное | Базовый pack |

**Пробел:** между 10:00 и 20:30 нет presentation frame — только `steady` + scenario copy.

#### `CoachSessionPhase` (activity lifecycle — влияет на сценарий)

| Phase | Условие |
|-------|---------|
| pre | upcoming |
| during | active |
| immediatePost | just finished (≤60 min) |
| settledPost | finished, не evening clock |
| evening | finished + timeOfDay ∈ {evening, lateEvening} |
| tomorrowProtection | engine override |
| idle | нет фокуса |

**Важно:** `evening` session phase только при 18:00+. В 10:47 после прогулки → `settledPost`, сценарий `walkAfterHeavyLoad` (completed).

#### `CoachCopyNutritionTiming.isWindDown`

| Guard | Часы |
|-------|------|
| isWindDown | 21:00+ |
| isSleepNow | 23:00+ |
| dayClosing candidate | 20:30+ |

### 1.3 Матрица: сценарий × фаза × уместность copy

| Сценарий (пример) | 08:00 | 10:47 | 14:00 | 18:30 | 22:00 |
|-------------------|-------|-------|-------|-------|-------|
| morningReadiness | ✅ morning brief | ⚠️ уже не morning branch | — | — | — |
| stableDay / workBanked | ✅ | ❌ «остаток дня» | ❌ «остаток дня» | ⚠️ ок | ✅ wind-down overlay |
| recoveryAfterHeavyYesterday | ✅ | ⚠️ avoid «с утра» | ✅ | ✅ | ✅ dayClosing |
| walkAfterHeavyLoad completed | ⚠️ «плотный день позади» | ❌ «день завершить» | ❌ | ⚠️ | ✅ |
| tomorrowProtection | rare | ❌ «на сегодня достаточно» | ❌ | ✅ | ✅ |
| postEnduranceSettled | ✅ present | ✅ present | ✅ | → eveningAfter* | evening copy |
| eveningAfterEndurance | — | — | — | ✅ | ✅ |

---

## 2. Conversation Timing Audit — нарушения

### 2.1 Критические (звучит как вечер утром/днём)

| Файл | RU фраза | Когда срабатывает | Проблема |
|------|----------|-------------------|----------|
| `CoachWalkAfterHeavyLoadCopy` | «день можно **завершить** спокойно» | completed, любое время | Past-as-closure в 10:47 |
| `CoachWalkAfterHeavyLoadCopy` | «**Остаток дня** спокойный» | completed | 12ч впереди — звучит как вечер |
| `CoachWalkAfterHeavyLoadCopy` | «**Плотный день позади**» | upcoming (!) | Future walk, но день «позади» |
| `CoachStableDayCopy` | «**Остаток дня** без спешки» | workBanked, не midday | Нет guard на remaining day |
| `CoachStableDayProfile` | «**Остаток дня** — восстановление» | teaser workBanked | Всегда |
| `CoachCopyRegistry` | «**На сегодня** нагрузки уже достаточно» | tomorrowProtection | Assessment без windDown guard |
| `CoachCopyRegistry` | «**Остаток дня** спокойный» | tomorrowProtection, !windDown | 10–20:59 |
| `CoachBodyStateCopyRenderer` | «на **остаток дня**» | workBanked + fatigued | Любое время |
| `CoachWalkRecoveryActionCopy` | «держите **остаток дня**» | completed | Любое время |

### 2.2 Средние (временная лексика без привязки к часам)

| Файл | RU фраза | Проблема |
|------|----------|----------|
| `CoachCopyRegistry` recoveryAfterHeavyYesterday | avoid: «не добавляйте тяжести **с утра**» | При midday assessment — «с утра» уже прошло |
| `CoachStableDayCopy` emptyDay | «догонять **вечером**» | Допустимо как future warning, но teaser днём звучит странно |
| `CoachStableDayCopy` tomorrowReserveFresh | «**завершите день пораньше**» | В 10:00 — преждевременно |
| `CoachTeaserCopy` tomorrowProtection | «Сегодня уже **достаточно**» | Title без time guard |
| `CoachCopyRegistryScenarios` eveningAfter* | «**вечер** для спокойного финиша» | ✅ только при sessionPhase.evening (18+) |

### 2.3 Корректно ограничено (эталон)

| Механизм | Guard |
|----------|-------|
| `CoachDayClosingCopyPolicy` | conversationPhase == .dayClosing + ≥20:30 + no upcoming |
| `CoachCopyNutritionTiming` windDown variants | ≥21:00 |
| `CoachStableDayCopy.earlyDoneWorkBankedPack` | timeOfDay == .midday only |
| `CoachMorningBriefCopyPolicy` | timeOfDay == .morning для recovery/protect branches |
| `CoachConversationNutritionPolicy` | suppress fuel/hydration in morningOverview/dayClosing |
| `CoachUpcomingActivityPolicy` | blocks dayClosing + tomorrowProtection override |

---

## 3. Past / Present / Future correctness

### 3.1 Классификация проблемных строк

| Фраза | Заявленный tense | Реальный tense @ 10:47 | Вердикт |
|-------|------------------|------------------------|---------|
| «Вчерашняя нагрузка ещё чувствуется» | Past → Present | ✅ | OK |
| «Плотный день позади» (upcoming walk) | Past | Future activity | ❌ |
| «Основная работа сделана» | Past | ✅ if work done | OK |
| «день можно завершить» | Present closure | Future (день не кончен) | ❌ |
| «Остаток дня спокойный» | Present + Future | Future-heavy | ⚠️ @ 10:47 |
| «не добавляйте тяжести с утра» | Future | Past (утро прошло) | ❌ @ midday |
| «Завтра в календаре серьёзная работа» | Future | ✅ | OK |
| «Поужинайте спокойно» | Present meal | ❌ @ 10:30 | ❌ (meal timing) |

### 3.2 Правило для copy-автора

```
Assessment  → Past + Present (что было, что сейчас)
Recommendation → Present + Future (что делать дальше сегодня)
Avoid → Future (чего не делать до конца дня)
NextAction → Present (один шаг в ближайшие 30–60 мин)
```

**Closure language** («достаточно», «завершить», «позади» как день) — только при `remainingDayBand == .closing` **и** `!hasMeaningfulActivityLaterToday`.

---

## 4. Remaining Day Awareness

### 4.1 Текущее состояние

- `CoachUpcomingActivityPolicy.hasMeaningfulActivityLaterToday` — **есть**, используется для dayClosing и tomorrowProtection routing.
- **Нет** `remainingDayBand` (early / mid / late / closing).
- Copy layer **не** получает «сколько часов осталось».

### 4.2 Предлагаемые bands

| Band | Условие | Разрешённая лексика |
|------|---------|---------------------|
| `.early` | <12:00 или >8h until 22:00 | «сегодня», «далее», «позже», «впереди» |
| `.mid` | 12:00–17:59 | «во второй половине дня», «до вечера» |
| `.late` | 18:00–20:59 | «остаток дня», «к вечеру» |
| `.closing` | ≥21:00 или dayClosing phase | «на сегодня достаточно», «завершить день», «перед сном» |

### 4.3 Пример 10:47

- `remainingDayBand` = **`.early`**
- Запрещено: «остаток дня», «на сегодня достаточно», «день позади», «завершить день»
- Разрешено: «сегодня без лишней интенсивности», «до вечера держите день лёгким», «если позже захочется — лёгкая активность»

---

## 5. Scheduled Activities Awareness

### 5.1 Что работает

`CoachUpcomingActivityPolicy` блокирует:
- `conversationPhase = .dayClosing`
- Engine override `tomorrowProtection` когда есть work ahead

### 5.2 Что не работает

Post-activity copy (`walkAfterHeavyLoad` completed, `stableDay` workBanked) **не проверяет** upcoming activities.

**Сценарий:** 09:20 walk done, 18:00 strength planned → в 10:47 Coach: «день можно завершить» ❌

**Нужно:** если `hasMeaningfulActivityLaterToday` → recommendation про recovery *до следующего блока*, не closure.

---

## 6. Previous Activity Awareness

### 6.1 Проблема «одна прогулка = день закончен»

`CoachWalkRecoveryActionCopy.phase` → `.completed` при `settledPost` / `evening` / `finished`.

Completed draft (`CoachWalkAfterHeavyLoadCopy`):
- «Основная работа уже сделана — **день можно завершить**»
- Не различает: только walk vs serious work + walk vs work + ещё тренировка впереди.

### 6.2 Частичные mitigations

- `hasSeriousWork` в presentation chrome меняет title («Восстанавливаемся» vs «Плотный день позади»)
- `earlyDoneWorkBankedPack` только для `stableDay` + `midday`
- Нет аналога для walk scenarios

---

## 7. Nutrition Timing Audit

### 7.1 Что есть

| Guard | Поведение |
|-------|-----------|
| `CoachConversationNutritionPolicy` | Нет deficit urgency в morningOverview / dayClosing |
| `CoachCopyNutritionTiming.isMealWindowOpen` | Полноценный meal advice до 21:00 |
| `fuelCatchUpNextAction` | «Нормально поешьте, пока не поздно» днём |
| Morning brief | «Лёгкий завтрак…» только при planned activity + morning |

### 7.2 Пробелы

| Проблема | Пример |
|----------|--------|
| Нет IF / eating window | 10:30 intermittent fasting → «пора завтракать» из morning brief |
| `fuelCatchUpNextAction` без user meal schedule | «Нормально поешьте» в любой meal window |
| Hydration как main story | `hydrationBehindSignal` может попасть в Why rows днём без risk |
| Legacy fasting | `WeekFit/Features/Nutrition/new/engine/CoachCopy.swift` — **не подключён** к new Coach pipeline |

### 7.3 Рекомендация

«Первый приём пищи — в привычное для вас время» когда:
- `brain.mealPattern` / user fasting preference указывает на позднее окно
- `timeOfDay` < usual first meal hour

---

## 8. Hydration Timing Audit

- Wind-down: «немного воды» ✅
- Daytime: «стакан воды в ближайший час» — OK как supporting signal
- **Риск:** при `fuelBehind` + `hydrationBehind` оба попадают в nextAction/Why — hydration не должна быть *главной историей* без `hydrationCritical` или active session
- `CoachCopyQualityAudit` уже проверяет fuel/hydration leak в main story — ✅

---

## 9. Copy Language Audit — каталог запрещённых фраз

### 9.1 Запрещено утром и днём (05:00–17:59)

| RU | EN equivalent |
|----|---------------|
| На сегодня достаточно | Enough for today |
| Заканчивайте день | Wind down the day |
| Завершаем день | Closing the day |
| День позади | Day is behind you |
| День закончился / можно завершить день | Day is over |
| Уже всё сделано (как closure) | Already done (closure) |
| Перед сном | Before bed |
| Ложитесь / укладывайтесь | Go to bed |
| Вечерний ритуал | Evening ritual |
| Поужинайте | Have dinner |
| Вечер без нагрузки (как fact) | Evening without load |
| Остаток дня * | Rest of the day * |

\* «Остаток дня» — **запрещено до 18:00**; с 18:00 — допустимо; с 21:00 — preferred для wind-down.

### 9.2 Запрещено днём (05:00–11:59)

| RU | Причина |
|----|---------|
| С утра (в avoid) | Утро уже прошло после 11:00 |
| Завершите день пораньше | Преждевременное closure |
| Плотный день позади (если впереди work) | Ложный past closure |

### 9.3 Разрешено только Wind Down (21:00+) / dayClosing

| RU |
|----|
| На сегодня достаточно |
| Решите, во сколько ложитесь |
| Вечер без лишней нагрузки |
| Начните вечерний ритуал |
| Сбавьте обороты — сон важнее |

### 9.4 Альтернативы для early/mid day

| Вместо | Использовать |
|--------|--------------|
| Остаток дня спокойный | Сегодня без лишней интенсивности |
| День можно завершить | Основная работа сделана — дальше легко |
| На сегодня достаточно | На сегодня серьёзной работы уже хватит |
| Плотный день позади (upcoming) | После нагрузки — прогулка поможет успокоиться |
| Пора завтракать | Первый приём пищи — в привычное время |

---

## 10. Real Coach Test — примеры @ 10:47

| Сценарий | Сейчас говорит | Живой тренер сказал бы | Вердикт |
|----------|----------------|------------------------|---------|
| walkAfterHeavyLoad completed | «день можно завершить спокойно» | «Прогулка помогла — до вечера держите день лёгким» | ❌ |
| stableDay workBanked | «Остаток дня без спешки» | «Утренняя работа сделана — дальше без тяжёлых блоков» | ❌ (есть earlyDone только для midday assessment, не recommendation) |
| recoveryAfterHeavyYesterday | «сегодня мягче» + avoid «с утра» | «Вчера ещё в ногах — сегодня без спешки» | ⚠️ |
| tomorrowProtection | «На сегодня нагрузки уже достаточно» | «Серьёзная работа уже сделана — берегите силы на завтра» | ⚠️ |
| morningReadiness @ 10:47 | generic stable/recovery (не morning branch) | Должен помнить утренний контекст или переключиться на midday tone | ⚠️ |
| lowRecoveryPrep + ride at 14:00 | «Впереди серьёзная выносливость» | ✅ | ✅ |

---

## 11. Архитектура: presentation layer без смены routing

### 11.1 Принцип (уже в контракте)

> `CoachConversationPhase` и timing overlays **не меняют** `CoachScenarioKey`, focus, safety.

### 11.2 Предлагаемый слой: `CoachConversationPresentationFrame`

Новый **read-only** контекст для copy layer (не в ScenarioResolver):

```swift
struct CoachConversationPresentationFrame: Equatable, Sendable {
    let timeBand: CoachTimeBand          // morningOpening | morning | midday | afternoon | evening | windDown
    let remainingDayBand: CoachRemainingDayBand  // early | mid | late | closing
    let tensePolicy: CoachCopyTensePolicy        // разрешённые past/present/future markers
    let hasWorkLaterToday: Bool
    let hasWorkDoneToday: Bool
    let closureAllowed: Bool                     // derived: closing band + !hasWorkLaterToday
}
```

**Вычисляется в** `CoachEngine.finalizeContext` рядом с `conversationPhase` — из `now`, `timeOfDay`, `CoachUpcomingActivityPolicy`, `conversationPhase`.

### 11.3 Pipeline (после имплементации)

```
CoachScenarioResolver → CoachScenarioKey (unchanged)
CoachCopyRegistry → base pack (unchanged)
CoachConversationCopyPolicy.apply(pack, frame:) → time-aware wording
CoachDayClosingCopyPolicy.apply (if dayClosing)
CoachBodyStateCopyRenderer (existing)
```

### 11.4 `CoachConversationCopyPolicy` (новый)

Ответственность:
1. **Phrase substitution** по `remainingDayBand` («остаток дня» → «сегодня» в early)
2. **Branch selection** в registry helpers (расширить pattern `windDown` → `frame.closureAllowed`)
3. **Forbidden phrase audit** — `CoachConversationTimingAudit` at build time

Не делает:
- Не выбирает сценарий
- Не меняет focus / sessionPhase

### 11.5 `CoachConversationTimingAudit` (новый, по аналогии с LanguageAudit)

```swift
enum CoachConversationTimingAudit {
    static func audit(pack: CoachCopyPack, frame: CoachConversationPresentationFrame) -> Report
}
```

Правила:
- IF `!frame.closureAllowed` AND text matches `forbiddenClosurePhrases` → violation
- IF `frame.timeBand == .morningOpening` AND text matches `eveningOnlyPhrases` → violation
- IF `frame.hasWorkLaterToday` AND text implies day complete → violation

### 11.6 Изменения по файлам (приоритет)

| P | Файл | Изменение |
|---|------|-----------|
| P0 | `CoachWalkAfterHeavyLoadCopy` | completed/upcoming drafts + frame |
| P0 | `CoachStableDayCopy` / `CoachStableDayProfile` | workBanked teasers + recommendation |
| P0 | `CoachCopyRegistry` tomorrowProtection | assessment/recommendation branches |
| P1 | `CoachBodyStateCopyRenderer` | «остаток дня» → frame-aware |
| P1 | `CoachCopyRegistry` recoveryAfterHeavyYesterday | avoid без «с утра» после 11:00 |
| P1 | `CoachConversationPresentationFrame` | новый тип + resolver |
| P2 | `CoachCopyNutritionTiming` | IF-aware meal copy |
| P2 | `CoachConversationTimingAudit` + tests | CI guard |
| P3 | Align `CoachTimeOfDay` buckets с ТЗ (10–12 = morning) | breaking change — отдельный PR |

---

## 12. Таблица сценариев — summary violations

| CoachScenarioKey | Timing risk | Основная проблема |
|------------------|-------------|-------------------|
| stableDay (workBanked) | High | «Остаток дня» без band guard |
| walkAfterHeavyLoad | High | Closure после одной прогулки |
| walkRecoveryAction | Medium | «Остаток дня» в completed |
| tomorrowProtection | High | «На сегодня достаточно» днём |
| recoveryAfterHeavyYesterday | Medium | «с утра» в avoid после полудня |
| protectTomorrowFresh | Low | OK с morning branch |
| morningReadiness | Medium | Теряет morning copy после 10:00 |
| post*Settled | Low | Present-tense OK |
| eveningAfter* | Low | Correctly gated 18:00+ |
| stableDay + dayClosing | Low | Overlay корректен |
| lowRecoveryPrep | Low | Future-oriented ✅ |
| during* / active* | Low | Live copy ✅ |

---

## 13. Рекомендуемые next steps

1. **P0 copy fixes** — walkAfterHeavyLoad, stableDay workBanked, tomorrowProtection (без новых типов, только ветки по `timeOfDay` + `hasMeaningfulActivityLaterToday`)
2. **`CoachConversationPresentationFrame`** — единый источник для copy policies
3. **`CoachConversationTimingAudit`** — тесты на baseline packs × 4 time snapshots (08, 11, 15, 22)
4. **IF integration** — подключить meal window из user profile к `CoachCopyNutritionTiming`
5. **Align time buckets** — обсудить сдвиг morning до 12:00 vs оставить 10:00 cutoff

---

## Appendix: ключевые файлы

| Concern | Path |
|---------|------|
| Time buckets | `Context/CoachContext.swift` |
| Conversation phase | `Context/CoachConversationPhaseResolver.swift` |
| Day closing overlay | `Copy/CoachDayClosingCopyPolicy.swift` |
| Wind-down nutrition | `Copy/CoachCopyNutritionTiming.swift` |
| Upcoming gate | `Context/CoachUpcomingActivityPolicy.swift` |
| Walk copy | `Copy/CoachWalkAfterHeavyLoadCopy.swift` |
| Stable day | `Context/CoachStableDayProfile.swift` |
| Safety contract | `Docs/CoachConversationPhaseSafetyContract.md` |
| Edge cases | `Docs/CoachEdgeCaseMatrix.md` |
