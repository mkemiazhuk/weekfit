import Foundation

/// Copy packs for scenarios beyond Phase 1 — same voice as `CoachV6CopyRegistry`.
enum CoachV6CopyRegistryScenarios {

    struct Draft: Equatable {
        let assessment: CoachV6BilingualText
        let recommendation: CoachV6BilingualText
        let avoid: CoachV6BilingualText
        let nextAction: CoachV6BilingualText
    }

    static func draft(for scenario: CoachV6ScenarioKey, input: CoachV6CopyBuildInput) -> Draft? {
        switch scenario {
        case .activeEndurance:
            return activeEndurance(input: input)
        case .postEnduranceImmediate:
            return postEnduranceImmediate(input: input)
        case .postEnduranceSettled:
            return postEnduranceSettled(input: input)
        case .eveningAfterEndurance:
            return eveningAfterEndurance(input: input)
        case .activeRacket:
            return activeRacket(input: input)
        case .duringRacket:
            return duringRacket(input: input)
        case .postRacketImmediate:
            return postRacketImmediate(input: input)
        case .postRacketSettled:
            return postRacketSettled(input: input)
        case .eveningAfterRacket:
            return eveningAfterRacket(input: input)
        case .activeStrength:
            return activeStrength(input: input)
        case .duringStrength:
            return duringStrength(input: input)
        case .postStrengthImmediate:
            return postStrengthImmediate(input: input)
        case .postStrengthSettled:
            return postStrengthSettled(input: input)
        case .eveningAfterStrength:
            return eveningAfterStrength(input: input)
        case .walkLightDay:
            return walkLightDay()
        case .walkEveningWindDown:
            return walkEveningWindDown()
        case .walkRecoveryAction:
            return walkRecoveryAction()
        case .activeRecovery:
            return activeRecovery(input: input)
        case .duringRecovery:
            return duringRecovery(input: input)
        case .postRecoveryImmediate:
            return postRecoveryImmediate(input: input)
        case .postRecoverySettled:
            return postRecoverySettled(input: input)
        case .eveningAfterRecovery:
            return eveningAfterRecovery(input: input)
        case .saunaPreparation:
            return saunaPreparation(input: input)
        case .saunaActive:
            return saunaActive()
        case .saunaRecovery:
            return saunaRecovery(input: input)
        default:
            return nil
        }
    }

    // MARK: - Endurance

    private static func activeEndurance(input: CoachV6CopyBuildInput) -> Draft {
        let assessment: CoachV6BilingualText
        switch input.activityType {
        case .cycling:
            assessment = .en(
                "Ride is coming — time to settle pace and legs.",
                "Заезд впереди — пора настроить темп и ноги."
            )
        case .running:
            assessment = .en(
                "Run is ahead — dial in effort before the first mile.",
                "Пробежка впереди — настройте усилие до первого километра."
            )
        default:
            assessment = .en(
                "Session is ahead — arrive calm, not already chasing.",
                "Тренировка впереди — выходите спокойно, без гонки с порога."
            )
        }

        return Draft(
            assessment: assessment,
            recommendation: .en(
                "Start easy — let breathing and rhythm find their place.",
                "Начните легко — пусть дыхание и ритм сами найдутся."
            ),
            avoid: .en(
                "Don't open with a sprint or heavy gear.",
                "Не стартуйте рывком или тяжёлой передачей."
            ),
            nextAction: .en(
                "Five minutes easy warm-up, then check the plan.",
                "Пять минут лёгкой разминки — потом сверьтесь с планом."
            )
        )
    }

    private static func postEnduranceImmediate(input: CoachV6CopyBuildInput) -> Draft {
        let assessment: CoachV6BilingualText
        switch input.activityType {
        case .cycling:
            assessment = .en(
                "Ride is done — legs are still spinning inside.",
                "Заезд позади — ноги ещё крутятся внутри."
            )
        case .running:
            assessment = .en(
                "Run is done — heart rate is still catching up.",
                "Пробежка позади — пульс ещё не успокоился."
            )
        default:
            assessment = .en(
                "Session just ended — body is still buzzing.",
                "Тренировка только что закончилась — тело ещё на волне."
            )
        }

        return Draft(
            assessment: assessment,
            recommendation: .en(
                "Ten easy minutes, then refuel and rehydrate.",
                "Десять минут легко — потом еда и вода."
            ),
            avoid: .en(
                "Don't sit down hard or skip the cooldown.",
                "Не падайте на диван сразу — не пропускайте заминку."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Walk five minutes before you stop moving.",
                    "Пять минут пройдитесь, прежде чем остановиться."
                )
            )
        )
    }

    private static func postEnduranceSettled(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Endurance work is banked — recovery is the job now.",
                "Заезд сделан — сейчас задача восстановиться."
            ),
            recommendation: .en(
                "Keep the next hour unhurried — legs need quiet.",
                "Следующий час без спешки — ногам нужна тишина."
            ),
            avoid: .en(
                "Don't stack another hard block on tired legs.",
                "Не добавляйте ещё один тяжёлый блок на уставшие ноги."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Stretch calves and hips for ten minutes.",
                    "Потяните икры и бёдра минут десять."
                )
            )
        )
    }

    private static func eveningAfterEndurance(input: CoachV6CopyBuildInput) -> Draft {
        let windDown = CoachV6CopyNutritionTiming.isWindDown(input.timeOfDay)
        return Draft(
            assessment: .en(
                "Big endurance day — evening is for landing softly.",
                "Большой день на ногах — вечер для спокойного финиша."
            ),
            recommendation: windDown
                ? .en(
                    "Wind down now — sleep carries tomorrow's legs.",
                    "Сбавьте обороты — завтрашние ноги начинаются со сна."
                )
                : .en(
                    "Keep the rest of today easy — nothing to prove tonight.",
                    "Остаток дня лёгкий — вечером нечего доказывать."
                ),
            avoid: .en(
                "No late hard efforts or long screen time in bed.",
                "Без поздних нагрузок и экрана перед сном."
            ),
            nextAction: windDown
                ? CoachV6CopyNutritionTiming.windDownSleepNextAction()
                : catchUpNextAction(
                    input: input,
                    defaultAction: .en(
                        "Eat something balanced, then start settling in.",
                        "Поужинайте спокойно — и начинайте укладываться."
                    )
                )
        )
    }

    // MARK: - Racket

    private static func activeRacket(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Match is close — sharp mind beats rushed legs.",
                "Игра скоро — ясная голова важнее торопливых ног."
            ),
            recommendation: .en(
                "Warm up shoulders and feet — controlled first games.",
                "Разогрейте плечи и стопы — первые геймы под контролем."
            ),
            avoid: .en(
                "Don't go all-out in the first rally.",
                "Не выкладывайтесь в первом розыгрыше."
            ),
            nextAction: .en(
                "Hit easy for five minutes, then pick your pace.",
                "Пять минут легко — потом выберите свой темп."
            )
        )
    }

    private static func duringRacket(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "You're in the match — every point counts now.",
                "Вы в игре — каждый розыгрыш на счету."
            ),
            recommendation: .en(
                "Breathe out on the swing — reset between points.",
                "Выдыхайте на ударе — между очками успевайте сброс."
            ),
            avoid: .en(
                "Don't chase every ball at full stretch.",
                "Не лезьте за каждым мячом на пределе."
            ),
            nextAction: .en(
                "Use changeovers — towel off, one deep breath.",
                "Между геймами — вытрите пот, один глубокий вдох."
            )
        )
    }

    private static func postRacketImmediate(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Match over — legs and nerves are still lit up.",
                "Игра позади — ноги и нервы ещё горят."
            ),
            recommendation: .en(
                "Walk the court off — let heart rate drift down.",
                "Пройдитесь по корту — пусть пульс сам снизится."
            ),
            avoid: .en(
                "Don't collapse into a chair without moving.",
                "Не падайте на стул сразу — походите."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Five minutes easy walk, then drink.",
                    "Пять минут лёгкой ходьбы — потом пейте."
                )
            )
        )
    }

    private static func postRacketSettled(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Court work is done — muscles need quiet now.",
                "Корт позади — мышцам сейчас нужна тишина."
            ),
            recommendation: .en(
                "Light food and fluids — nothing heavy on the stomach.",
                "Лёгкая еда и вода — без тяжести в желудке."
            ),
            avoid: .en(
                "Don't jump into another intense session tonight.",
                "Не прыгайте сегодня в ещё одну интенсивную сессию."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Roll or stretch shoulders for ten minutes.",
                    "Прокатайте или растяните плечи минут десять."
                )
            )
        )
    }

    private static func eveningAfterRacket(input: CoachV6CopyBuildInput) -> Draft {
        let windDown = CoachV6CopyNutritionTiming.isWindDown(input.timeOfDay)
        return Draft(
            assessment: .en(
                "Racket day is in the books — evening is for recovery.",
                "Игровой день позади — вечер для восстановления."
            ),
            recommendation: windDown
                ? .en(
                    "Ease into the night — tomorrow's legs start with sleep.",
                    "Плавно в ночь — завтрашние ноги начинаются со сна."
                )
                : .en(
                    "Keep it calm — no extra court time tonight.",
                    "Спокойно — без лишней игры сегодня вечером."
                ),
            avoid: .en(
                "No late drills or heavy legs before bed.",
                "Без поздних отработок и тяжёлых ног перед сном."
            ),
            nextAction: windDown
                ? CoachV6CopyNutritionTiming.windDownSleepNextAction()
                : catchUpNextAction(
                    input: input,
                    defaultAction: .en(
                        "Shower, eat lightly, then unplug.",
                        "Душ, лёгкий ужин — и отложите дела."
                    )
                )
        )
    }

    // MARK: - Strength

    private static func activeStrength(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Strength block is next — prime the body, not the ego.",
                "Силовая впереди — разогрейте тело, не амбиции."
            ),
            recommendation: .en(
                "Warm up joints and first sets light — form first.",
                "Разогрейте суставы — первые подходы легко, форма важнее."
            ),
            avoid: .en(
                "Don't load max weight on cold muscles.",
                "Не ставьте максимум на холодные мышцы."
            ),
            nextAction: .en(
                "Ten minutes mobility, then your opening sets.",
                "Десять минут мобильности — потом первые подходы."
            )
        )
    }

    private static func duringStrength(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "You're under load — reps and sets are live.",
                "Вы под нагрузкой — повторения и подходы идут."
            ),
            recommendation: .en(
                "Rest enough to keep form clean on every rep.",
                "Отдыхайте столько, чтобы форма не ломалась."
            ),
            avoid: .en(
                "Don't rush sets or chase numbers with bad form.",
                "Не гоните подходы и цифры ценой техники."
            ),
            nextAction: .en(
                "Before the next set — two breaths, brace, go.",
                "Перед следующим подходом — два вдоха, корпус, в работу."
            )
        )
    }

    private static func postStrengthImmediate(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Last set done — muscles are still loaded and warm.",
                "Последний подход сделан — мышцы ещё горячие."
            ),
            recommendation: .en(
                "Walk five minutes — let blood flow settle.",
                "Пять минут пройдитесь — пусть кровоток успокоится."
            ),
            avoid: .en(
                "Don't skip cooldown or sit stiff right away.",
                "Не пропускайте заминку и не застывайте сразу."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Protein and fluids within the next hour.",
                    "Белок и вода в ближайший час — будет кстати."
                )
            )
        )
    }

    private static func postStrengthSettled(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Strength work is banked — repair starts now.",
                "Силовая сделана — ремонт начинается сейчас."
            ),
            recommendation: .en(
                "Easy movement and food — muscles rebuild on rest.",
                "Лёгкое движение и еда — мышцы растут на отдыхе."
            ),
            avoid: .en(
                "Don't pile on another heavy session tonight.",
                "Не накладывайте сегодня ещё одну тяжёлую сессию."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Stretch what you trained for ten minutes.",
                    "Потяните то, что тренировали, минут десять."
                )
            )
        )
    }

    private static func eveningAfterStrength(input: CoachV6CopyBuildInput) -> Draft {
        let windDown = CoachV6CopyNutritionTiming.isWindDown(input.timeOfDay)
        return Draft(
            assessment: .en(
                "Heavy strength day — evening is for landing, not loading.",
                "Тяжёлый силовой день — вечер без новой нагрузки."
            ),
            recommendation: windDown
                ? .en(
                    "Wind down — sleep is where strength settles in.",
                    "Сбавьте обороты — сила уложится во сне."
                )
                : .en(
                    "Keep the rest of today light on the legs.",
                    "Остаток дня лёгкий для ног."
                ),
            avoid: .en(
                "No late sets or heavy stairs before bed.",
                "Без поздних подходов и тяжёлых лестниц перед сном."
            ),
            nextAction: windDown
                ? CoachV6CopyNutritionTiming.windDownSleepNextAction()
                : catchUpNextAction(
                    input: input,
                    defaultAction: .en(
                        "Eat, shower, then start your wind-down.",
                        "Поужинайте, душ — и начинайте расслабляться."
                    )
                )
        )
    }

    // MARK: - Walk

    private static func walkLightDay() -> Draft {
        Draft(
            assessment: .en(
                "Easy walk day — movement without a scoreboard.",
                "Лёгкая прогулка — движение без задачи."
            ),
            recommendation: .en(
                "Keep it pleasant — fresh air beats forced steps.",
                "Приятный темп — свежий воздух лучше насильных шагов."
            ),
            avoid: .en(
                "Don't turn it into a power walk or errands sprint.",
                "Не превращайте в спортивную ходьбу или забег по делам."
            ),
            nextAction: .en(
                "Twenty easy minutes — phone optional, pace low.",
                "Двадцать минут легко — телефон по желанию, темп низкий."
            )
        )
    }

    private static func walkEveningWindDown() -> Draft {
        Draft(
            assessment: .en(
                "Evening walk — help the day settle before sleep.",
                "Вечерняя прогулка — день пусть уложится перед сном."
            ),
            recommendation: .en(
                "Slow pace, soft light — nothing to chase.",
                "Медленный темп, мягкий свет — некуда спешить."
            ),
            avoid: .en(
                "Don't pick up pace or take calls that rev you up.",
                "Не ускоряйтесь и не берите звонки, что будоражат."
            ),
            nextAction: .en(
                "Fifteen quiet minutes, then head toward bed.",
                "Пятнадцать тихих минут — потом к постели."
            )
        )
    }

    private static func walkRecoveryAction() -> Draft {
        Draft(
            assessment: .en(
                "Short walk to flush the legs after hard work.",
                "Короткая прогулка — разогнать ноги после нагрузки."
            ),
            recommendation: .en(
                "Easy steps only — blood flow, not more load.",
                "Только лёгкие шаги — кровоток, не новая нагрузка."
            ),
            avoid: .en(
                "Don't speed up or add hills for extra credit.",
                "Не ускоряйтесь и не лезьте в горки ради галочки."
            ),
            nextAction: .en(
                "Ten minutes easy — slow enough to talk.",
                "Десять минут легко — так, чтобы спокойно говорить."
            )
        )
    }

    // MARK: - Mindful recovery

    private static func activeRecovery(input: CoachV6CopyBuildInput) -> Draft {
        let assessment: CoachV6BilingualText
        switch input.activityType {
        case .yoga:
            assessment = .en(
                "Yoga is next — arrive soft, not already tight.",
                "Йога впереди — приходите мягко, не зажатыми."
            )
        case .breathing:
            assessment = .en(
                "Breath work is ahead — quiet room, open chest.",
                "Дыхание впереди — тихое место, открытая грудь."
            )
        default:
            assessment = .en(
                "Recovery block is next — gentle from the first minute.",
                "Блок восстановления — мягко с первой минуты."
            )
        }

        return Draft(
            assessment: assessment,
            recommendation: .en(
                "Keep effort low — this is repair, not training.",
                "Держите усилие низким — это ремонт, не тренировка."
            ),
            avoid: .en(
                "Don't push depth or hold through pain.",
                "Не лезьте в глубину и не терпите боль."
            ),
            nextAction: .en(
                "Find a quiet spot and start with five easy breaths.",
                "Найдите тихое место — пять спокойных вдохов для старта."
            )
        )
    }

    private static func duringRecovery(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Recovery session is live — slow and present.",
                "Сессия восстановления идёт — медленно и внимательно."
            ),
            recommendation: .en(
                "Stay in easy range — nothing to prove here.",
                "Оставайтесь в лёгкой зоне — тут нечего доказывать."
            ),
            avoid: .en(
                "Don't chase depth or compare to yesterday.",
                "Не гонитесь за глубиной и не сравнивайте со вчера."
            ),
            nextAction: .en(
                "Notice where you hold tension — breathe into it.",
                "Заметьте, где зажим — выдыхайте туда."
            )
        )
    }

    private static func postRecoveryImmediate(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Session wrapped — calm should linger a few minutes.",
                "Сессия закончилась — спокойствие пусть останется."
            ),
            recommendation: .en(
                "Sit or lie still — let nervous system downshift.",
                "Посидите или полежите — пусть нервная система успокоится."
            ),
            avoid: .en(
                "Don't jump straight into noise or hard tasks.",
                "Не ныряйте сразу в шум и тяжёлые дела."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Five quiet minutes before you move on.",
                    "Пять тихих минут — потом можно двигаться дальше."
                )
            )
        )
    }

    private static func postRecoverySettled(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Recovery work is done — carry the calm forward.",
                "Восстановление сделано — сохраните это спокойствие."
            ),
            recommendation: .en(
                "Light movement and hydration — keep the softness.",
                "Лёгкое движение и вода — не теряйте мягкость."
            ),
            avoid: .en(
                "Don't rush back into stress or heavy training.",
                "Не возвращайтесь резко к стрессу или тяжёлым тренировкам."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Drink water and take ten easy minutes.",
                    "Выпейте воды и десять минут без спешки."
                )
            )
        )
    }

    private static func eveningAfterRecovery(input: CoachV6CopyBuildInput) -> Draft {
        let windDown = CoachV6CopyNutritionTiming.isWindDown(input.timeOfDay)
        return Draft(
            assessment: .en(
                "Recovery day is closing — protect the calm tonight.",
                "День восстановления заканчивается — берегите спокойствие."
            ),
            recommendation: windDown
                ? .en(
                    "Ease into sleep — rest is the final rep.",
                    "Плавно ко сну — отдых это последний подход."
                )
                : .en(
                    "Keep the evening quiet — no extra load.",
                    "Вечер тихий — без лишней нагрузки."
                ),
            avoid: .en(
                "No late screens or hard conversations in bed.",
                "Без поздних экранов и тяжёлых разговоров в постели."
            ),
            nextAction: windDown
                ? CoachV6CopyNutritionTiming.windDownSleepNextAction()
                : catchUpNextAction(
                    input: input,
                    defaultAction: .en(
                        "Dim lights and start your bedtime routine.",
                        "Приглушите свет — начните вечерний ритуал."
                    )
                )
        )
    }

    // MARK: - Sauna

    private static func saunaPreparation(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Sauna is next — calm entry beats heroic heat.",
                "Баня впереди — спокойный вход лучше героического жара."
            ),
            recommendation: .en(
                "Short first round — listen to your body early.",
                "Первый заход короткий — слушайте тело сразу."
            ),
            avoid: .en(
                "Don't enter right after heavy food or when overheated.",
                "Не заходите сразу после плотной еды или перегрева."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Cool rinse if you like, then step in gently.",
                    "Прохладное ополаскивание — и заходите мягко."
                )
            )
        )
    }

    private static func saunaActive() -> Draft {
        Draft(
            assessment: .en(
                "You're in the heat — body works hard without moving.",
                "Вы в жаре — тело работает, даже без движения."
            ),
            recommendation: .en(
                "Short rounds — cool breaks beat heroic sweats.",
                "Короткие заходы — прохладные паузы лучше героизма."
            ),
            avoid: .en(
                "Don't stay until dizzy — leave at the first warning sign.",
                "Не сидите до головокружения — выходите при первом сигнале."
            ),
            nextAction: .en(
                "Step out at the first sign of lightheadedness.",
                "Выйдите при первом лёгком головокружении."
            )
        )
    }

    private static func saunaRecovery(input: CoachV6CopyBuildInput) -> Draft {
        Draft(
            assessment: .en(
                "Heat session done — cool down slowly, not in a rush.",
                "Жар позади — остывайте медленно, без спешки."
            ),
            recommendation: .en(
                "Rest and quiet — let pulse settle before what's next.",
                "Отдых и тишина — пусть пульс успокоится."
            ),
            avoid: .en(
                "Don't jump into cold shower or hard work right away.",
                "Не ныряйте сразу в ледяной душ или тяжёлую работу."
            ),
            nextAction: catchUpNextAction(
                input: input,
                defaultAction: .en(
                    "Sit fifteen minutes quietly before you move on.",
                    "Пятнадцать минут тишины — потом можно двигаться."
                )
            )
        )
    }

    // MARK: - Helpers

    private static func catchUpNextAction(
        input: CoachV6CopyBuildInput,
        defaultAction: CoachV6BilingualText
    ) -> CoachV6BilingualText {
        if input.modifiers.fuelBehind || input.fuelState.isBehind {
            return CoachV6CopyNutritionTiming.fuelCatchUpNextAction(for: input)
        }
        if input.modifiers.hydrationBehind || input.hydrationState.isBehind {
            return CoachV6CopyNutritionTiming.hydrationCatchUpNextAction(for: input)
        }
        return defaultAction
    }
}
