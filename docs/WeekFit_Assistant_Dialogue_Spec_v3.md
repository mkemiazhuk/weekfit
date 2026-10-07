# WeekFit Assistant — спецификация диалогов v3

**Дата:** 6 октября 2026  
**Статус:** самодостаточная спецификация + карта на существующий ассистент  
**Локали:** EN / RU (без смешения в одной локали)  
**Исходник:** Spec v2 + реальная архитектура `CoachAssistantFlow`

---

## 0. Критерий успеха

После ветки человек понимает:

1. что видно по данным приложения;  
2. как это соотносится с целью / планом / personal baseline;  
3. что это значит с учётом выбранных ответов.

Пользователь не печатает. Навигация — готовые чипы (`option_id`). Маршрутизация только по `node_id` + `option_id`, никогда по тексту кнопки.

---

## 1. Архитектурное соответствие

| Слой | Компонент |
| --- | --- |
| Выбор сценария по данным | `CoachAssistantInsightBuilder` + `CoachAssistantSignalSnapshot` |
| Состояние разговора | `CoachAssistantConversation` |
| Тексты / локализация | `CoachAssistantCopy` (bilingual EN/RU) |
| UI сообщений и кнопок | `CoachAssistantChatView` + `CoachAssistantViewModel` |
| Действия приложения | `CoachAssistantChoiceAction` (Meals / Goals / Plan ease) |

### Карта Spec → код

| Spec `node_id` | Код `CoachAssistantNodeID` |
| --- | --- |
| `HELLO` | `feelingAsk` |
| `TOPIC` | `mindAsk` |
| `A_ENTRY` / `A_BRIEF` / `A_WORKOUT` | `activityGate` → `activityToday` |
| `A_RESULT` (effort) | `activityToday` + `activity.effort.*` |
| `N_ENTRY` / `N_COMPLETE` | `nutritionGate` |
| `N_PROGRESS` / `N_RESULT` | `nutritionRemaining` / `nutritionChooseMeal` / `nutritionHabits` |
| `R_ENTRY` / `R_BRIEF` | `recoveryGate` → `recoveryToday` |
| `R_TIRED` / `R_DURATION` | `tiredClarify` / `recoveryDuration` / `recoveryPattern` |
| `END` | `end` |

Стабильные `option_id` (фрагмент):  
`feeling.energized|okay|tired|low`, `mind.activity|nutrition|recovery`,  
`activity.effort.easy|moderate|hard`, `nutrition.remaining|helpChoose|habits`,  
`nutrition.log.complete.yes|no`, `recovery.justToday|fewDays`,  
`recovery.energy.normal|lower|notStarted`, `end.another|end.done`, `menu.finish`.

---

## 2. Состояние разговора

```
conversation_id
day_key
feeling: energized(good) | okay | tired | low | null
clarification / fatigue_type: lowEnergy | soreMuscles | sleepiness | null
fatigue_duration: justToday | fewDays | null   // recovery.justToday | recovery.fewDays
area / previous_area
answers: { option_id → answered_at }           // choiceIDs + TTL-политика
observations_shown: questionIDs / recommendationIDs (memory day)
data_version: evidence.analysisVersion + fingerprint сигналов
return_node_id: currentNodeID при уходе на внешний экран
last_conclusion: preview / последний coach turn
ended
```

**TTL (реализация):**
| Ответ | TTL | Инвалидация |
| --- | --- | --- |
| feeling | до конца календарного дня | `editFeeling` / меню «Изменить самочувствие» |
| fatigue_type / duration | пока feeling не сменён | смена feeling |
| workout_effort | привязан к сессии дня | новый completed workout / смена дня |
| food_log_complete | до смены дня или явного edit | `nutrition.log.complete.*` |
| area answers | пока area не сменена через `end.another` | смена темы сохраняет feeling |

**Правило пропуска:** если `option_id` уже в `choiceIDs` и TTL валиден — gate не переспрашивает (см. `isFreshTopicEntry`).

---

## 3. Реальные пороги приложения (`CoachFeelingEvidenceRules`)

Не выдумывать новые числа в диалоге:

| Параметр | Значение |
| --- | --- |
| Свежесть сна / recovery | ≤ 36 ч |
| Baseline lookback | 14 дней |
| Min sleep samples | 5 |
| Min recovery samples | 4 |
| Tired: sleep shortfall | ≥ 45 мин ниже baseline |
| Tired: recovery shortfall | ≥ 8 п.п. ниже baseline |
| Near baseline sleep | ±30 мин |
| Near baseline recovery | ±6 п.п. |
| Activity context window | 48 ч |

Missing ≠ 0. Неполный день не сравнивать с завершённым. Корреляция ≠ причина.

---

## 4. Глобальное меню (не чипы реплики)

| Действие | `option_id` / эффект |
| --- | --- |
| Другая тема | чип `end.another` → `TOPIC` (`mindAsk`), feeling сохранён |
| Изменить самочувствие | меню → `editFeeling` → `HELLO` с инвалидацией зависимых выводов |
| Начать заново | меню → новый `conversation_id` → `HELLO` |
| Завершить | меню `menu.finish` / чип `end.done` → `END` |
| Назад | системный dismiss чата (не шаг графа) |

---

## 5. Дерево узлов (самодостаточное)

### 5.1 Оболочка

#### `START`
1. Есть незавершённый разговор сегодня → восстановить (`continueConversation`) без повторного приветствия.  
2. Иначе → `HELLO`.

#### `HELLO` (`feelingAsk`)
**Реплика:** «{Good morning|afternoon|evening}, {name}. How are you feeling today?»  
RU: «Доброе утро/день/вечер, {name}. Как ты сегодня?»

**Кнопки:**
| option_id | label EN / RU | → |
| --- | --- | --- |
| `feeling.energized` | Good / Хорошо | сохранить feeling → insight → `TOPIC` |
| `feeling.okay` | Okay / Нормально | → `TOPIC` |
| `feeling.tired` | Tired / Устал | → `TOPIC` (тип усталости — в Recovery) |
| `feeling.low` | Not great / Не очень | → `TOPIC` |

После выбора: 1 короткое ack + ≤1 observation из данных + переход к topic chips.  
Не показывать отдельную анкету перед чатом.

#### `TOPIC` (`mindAsk`)
**Реплика:** «What shall we start with?» / «С чего начнём?»  
(при `end.another` — только чипы, без повторной фразы)

**Кнопки:** Activity / Nutrition / Recovery → `A_ENTRY` / `N_ENTRY` / `R_ENTRY`.

#### `END`
**Реплика:** короткое закрытие без нового совета; без обещаний «проверим завтра».  
**Кнопки:** опционально «Новый разговор».

---

### 5.2 Activity

#### `A_ENTRY` (`activityGate`)
1. Нет записей / плана / движения → `A_MISSING`.  
2. Есть completed сегодня → краткий brief + вопрос усилия (`A_WORKOUT`).  
3. Есть план без completed → brief + варианты (тренироваться / ease / другое).  
4. Иначе → recent / consistency.

#### `A_MISSING`
**Реплика:** «Свежих записей об активности пока нет.» (+ дата последних, если есть)  
**Кнопки:** Other topic · Done · (Open Plan если уместно)

#### `A_BRIEF` / `A_WORKOUT`
**Реплика:** факт сессии (label + минуты) + «How hard did that feel?» / «Как ощущалась нагрузка?»  
**Кнопки:**
| option_id | → |
| --- | --- |
| `activity.effort.easy` | `A_RESULT_EASY` |
| `activity.effort.moderate` | `A_RESULT_MODERATE` |
| `activity.effort.hard` | `A_RESULT_HARD` |

#### Итоги усилия (разные тексты)

**`A_RESULT_EASY`**  
EN: «The logged workout matched your plan, and it felt comfortable.» + next-step (план завтра / recovery при caution).  
RU: «Записанная тренировка совпала с планом, и тебе было комфортно.»  
*Запрещено:* «На сегодня этого достаточно.»

**`A_RESULT_MODERATE`**  
EN: «Got it — that session felt moderate.» + next-step.  
RU: «Понял — сессия ощущалась умеренно.»

**`A_RESULT_HARD`**  
EN: «That was a demanding session for you.» + softer evening / recovery / tomorrow plan.  
RU: «Для тебя это была требовательная сессия.»  
При caution (сон/recovery ниже usual): предложить Recovery, не диагностировать причину.

#### `A_STEPS` (если шаги доступны в signals/observациях)
**Реплика:** факт шагов сегодня vs 7d average **только** если ≥4 завершённых дня с данными; иначе абсолют + limit.  
«Does that match how the day went?»

**Кнопки → разные итоги:**
| option_id | Итог |
| --- | --- |
| `activity.steps.sat` | Согласовать с низким движением; не equаte missing device |
| `activity.steps.walkedMore` | Согласовать с высоким/обычным; отметить незавершённый день |
| `activity.steps.offDevice` | Limit: «Записи могут не показывать всё движение.» |
| `activity.steps.usual` | «Похоже на твой обычный день по шагам.» / без baseline — только абсолют |
| `activity.steps.unsure` | Факт без интерпретации ощущений |

*Fallback:* нет шагов → `A_STEPS_MISSING` (тренировки / другая тема / конец).

#### `A_LOAD_RECOVERY` (после hard / mismatch)
**Шаг 1 — уточнение (отдельная реплика):** «Когда больше чувствовалась усталость?»  
during / after / both / unsure.

**Шаг 2 — разбор (следующая реплика):** факты объёма + сон/recovery за те же даты **или** честный gap.  
«Это может сочетаться с усталостью, но само по себе не доказывает причину.»

**Кнопки:** Recovery (`R_ENTRY`, fatigue hints сохранены) · Подвести итог · Done.

---

### 5.3 Nutrition

#### `N_ENTRY` (`nutritionGate`)
**Реплика:** «What would help with food today?» / «Что будет полезно по питанию сегодня?»  
**Кнопки:** Next meal · What’s left · Habits · (Other/Done в closing)

#### `N_COMPLETE` (перед meal idea при неполном логе)
**Реплика:** «Is everything you’ve eaten so far already in the log?»  
**Кнопки:** Yes → meal idea / progress · No / Not sure → `N_PARTIAL`

#### `N_PARTIAL`
**Реплика:** «Then the numbers describe only what’s logged.»  
**Кнопки:** Open Meals · View logged (`N_RECORDED`) · Other topic

#### `N_PROGRESS` / `nutritionRemaining`
Открытый день — промежуточные цифры с конкретными значениями:

EN: «So far you’ve logged {cal} kcal and {pro} g protein toward {cal_goal} / {pro_goal}. The day isn’t finished, so this is a midpoint — not a final score.»  
RU: «К этому моменту: {cal} ккал и {pro} г белка при цели {cal_goal} / {pro_goal}. День ещё открыт — это промежуточные цифры.»

*Запрещено:* «До цели белка остаётся заметный запас» без чисел.  
*Запрещено:* «Менять рацион не требуется» → вместо этого:  
«По калориям и белку день близок к твоим ориентирам.» / «Calories and protein are close to your targets.»

Нет цели → абсолют + предложить Open Profile.  
Нет записей → `N_EMPTY` (не трактовать как 0 еды).

---

### 5.4 Recovery

Recovery = **сон + фазы + HRV + пульс покоя**. Производный recovery-% — вторичен (только если нет sleep/HRV/RHR, или как мягкая пометка mismatch).

#### `R_ENTRY`
1. Нет свежих sleep / HRV / RHR (и нет usable recovery-%) → `R_MISSING` (`unavailableHealthDataCopy`, формулировки про sleep/HRV/RHR).  
2. feeling ∈ {tired, low} и нет clarification → спросить тип (`R_TIRED` / `tiredClarify`) **если ещё не отвечал**.  
3. Иначе → сразу `R_BRIEF` (gate duration не обязателен при входе с TOPIC).

#### `R_MISSING`
**Реплика:** нет свежих данных о сне / HRV / пульсе покоя (не утверждать отказ в доступе, если `authorized != true`).  
**Кнопки:** Other topic · Done

#### `R_BRIEF` (`recoveryToday`)
Факты прошлой ночи в порядке приоритета:
1. Длительность сна vs usual (если baseline есть).  
2. Фазы: deep / REM / core — абсолютные минуты, без выдуманных baselines.  
3. HRV (ms) vs recent usual (если ≥3 дней).  
4. Resting HR vs recent usual (если ≥3 дней).  
5. Только если п.1–4 пусты: app recovery-% (+ usual, если есть) с пометкой, что деталей сна/HRV нет.

Закрытие: «readings from the log — not a diagnosis.»  
**Кнопки:** Last 7 nights · Other topic · Done

#### `R_NIGHTS` (`recovery.nights`)
Сводка за 7 дней: средний sleep / HRV / RHR по ночам с данными. Missing ≠ 0.

#### Мягкий mismatch (good/okay + derived recovery low)
К sleep/HRV-brief можно добавить одну фразу про app recovery-% ниже usual — без «you should rest» и без переопределения самочувствия.

#### `R_TIRED` → `R_DURATION` → path
Тип: sleepy / body / focus (существующие clarification).  
Длительность: just today / few days.  
Следующий шаг — снова sleep/HRV facts, не walk-first idea.

**Не предлагать** короткую прогулку как recovery idea, если уже есть заметная ходьба в логе.

---

### 5.5 Система / fallback

| Узел | Поведение |
| --- | --- |
| `OPEN_MEALS` / `OPEN_GOALS` / Plan review | существующие actions; `return_node_id` = текущий |
| `ACTION_FAILED` | «Не удалось открыть экран. Можно продолжить здесь.» → Other / Done |
| `REFRESH` | fingerprint изменился → короткое обновление 1 фактом, не полный опрос |
| `RESUME` | тот же узел; **не** перезапускать HELLO |
| Double-tap | `isProcessingChoice` блокирует повтор |
| Stale chip | очистка `choices` сразу после выбора |

---

## 6. Политика повторного входа

1. Не начинать день с полного опроса областей.  
2. Resume без повторного greeting.  
3. Данные ≈ те же → короткое обновление, не прежний опрос.  
4. Не обещать проверку завтра / уведомление без механизма.  
5. Weekly focus — retired.

---

## 7. Примеры (целевые транскрипты)

### 7.1 Activity — комфортная сессия
1. HELLO → Okay  
2. TOPIC → Activity  
3. Brief: «Силовая, 48 мин» → Easy  
4. «Записанная тренировка совпала с планом, и тебе было комфортно.» → Done

### 7.2 Nutrition — незавершённый день
1. HELLO → Good → Nutrition → What’s left  
2. «К этому моменту: 820 ккал и 38 г белка при цели 2000 / 120. День ещё открыт.» → Done

### 7.3 Recovery — sleep + soft mismatch
1. HELLO → Good → Recovery  
2. «Last night: ~7h — close to usual. Stages: deep … HRV … App recovery reading 58% is below usual ~70% — note the gap.» → Last 7 nights / Done

---

## 8. Покрытие состояний

Выше/ниже/около · нет цели · мало истории · partial/missing/stale · match/mismatch · «не знаю» · edit answer · смена area · resume · refresh · action error — обязательны.  
Шаги без данных, незаписанная активность, желание большей нагрузки — с limit_note, без автоизменения плана.

---

## 9. Качество

- У каждой кнопки есть целевой узел / option_id.  
- Нет автоциклов без действия человека.  
- Разные ответы → разные итоги.  
- Один tap → один переход.  
- SwiftUI re-render не дублирует turns (`didStart`, empty coachTurns на Other topic).  
- Feeling не форсит изменение плана.
