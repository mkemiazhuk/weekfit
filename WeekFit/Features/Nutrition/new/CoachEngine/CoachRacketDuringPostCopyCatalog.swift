import Foundation

enum CoachRacketDuringPostCopyCatalog {

    struct BilingualText: Hashable {
        let english: String
        let russian: String
    }

    struct ActionCopy {
        let type: CoachSupportActionTypeV3
        let title: BilingualText
        let subtitle: BilingualText
    }

    struct WindowCopy {
        let hero: BilingualText
        let assessment: BilingualText
        let situation: BilingualText
        let primary: ActionCopy
        let avoidance: BilingualText
        let extras: [ActionCopy]
    }

    struct ReasonCopy {
        let kind: CoachFinalStoryReason.Kind
        let english: String
        let russian: String
        let icon: String
        let colorFamily: CoachFinalStoryColorFamily
    }

    enum Phase {
        case warmIn
        case findRhythm
        case manageLoad
        case closeSmart
        case recoveryWindow
        case fueling
        case hydration
        case postLong
        case postMedium
        case postShort
    }

    enum Modality {
        case tennis
        case squash
        case general
    }

    enum PostTiming {
        case immediate
        case settled
        case stale

        static func from(minutesSinceEnd: Int) -> PostTiming {
            if minutesSinceEnd >= 240 { return .stale }
            if minutesSinceEnd >= 90 { return .settled }
            return .immediate
        }
    }

    struct PostContext {
        let recoveryPercent: Int
        let caloriesBurned: Double
        let shouldProtectTomorrow: Bool
        let timePhase: CoachFinalDecisionTimeOfDay
    }

    static func modality(for activity: PlannedActivity?) -> Modality {
        guard let activity else { return .general }
        let text = "\(activity.title) \(activity.type) \(activity.imageName)".lowercased()
        if text.contains("squash") { return .squash }
        if text.contains("tennis") { return .tennis }
        return .general
    }

    static func window(
        for phase: Phase,
        activity: PlannedActivity?,
        longSession: Bool,
        minutesSinceEnd: Int = 0,
        postContext: PostContext? = nil,
        referenceNow: Date? = nil
    ) -> WindowCopy {
        let sport = modality(for: activity)
        let postTiming = PostTiming.from(minutesSinceEnd: minutesSinceEnd)
        let resolveNow = referenceNow ?? Date()
        let remaining = CoachEnduranceDuringPostCopyCatalog.remainingMinutes(activity: activity, now: resolveNow)

        switch (phase, sport) {
        case (.warmIn, .tennis):
            return warmInTennis(longSession: longSession)
        case (.warmIn, .squash):
            return warmInSquash(longSession: longSession)
        case (.warmIn, .general):
            return warmInGeneral(longSession: longSession)
        case (.findRhythm, .tennis):
            return findRhythmTennis(longSession: longSession)
        case (.findRhythm, .squash):
            return findRhythmSquash(longSession: longSession)
        case (.findRhythm, .general):
            return findRhythmGeneral(longSession: longSession)
        case (.manageLoad, .tennis):
            return manageLoadTennis(longSession: longSession)
        case (.manageLoad, .squash):
            return manageLoadSquash(longSession: longSession)
        case (.manageLoad, .general):
            return manageLoadGeneral(longSession: longSession)
        case (.closeSmart, .tennis):
            return closeSmartTennis(longSession: longSession, remainingMinutes: remaining)
        case (.closeSmart, .squash):
            return closeSmartSquash(longSession: longSession, remainingMinutes: remaining)
        case (.closeSmart, .general):
            return closeSmartGeneral(longSession: longSession, remainingMinutes: remaining)
        case (.recoveryWindow, _):
            return recoveryWindow(sport: sport)
        case (.fueling, _):
            return fueling(sport: sport)
        case (.hydration, _):
            return hydration(sport: sport)
        case (.postLong, _):
            return postLong(timing: postTiming, context: postContext, sport: sport)
        case (.postMedium, _):
            return postMedium(timing: postTiming, context: postContext, sport: sport)
        case (.postShort, _):
            return postShort(timing: postTiming, context: postContext, sport: sport)
        }
    }

    static func reasons(
        for phase: Phase,
        activity: PlannedActivity?,
        elapsedMinutes: Int,
        remainingMinutes: Int?,
        recoveryPercent: Int,
        caloriesBurned: Double,
        shouldProtectTomorrow: Bool,
        minutesSinceEnd: Int = 0
    ) -> [ReasonCopy] {
        switch phase {
        case .warmIn:
            var items: [ReasonCopy] = []
            if let remainingMinutes, remainingMinutes > 0 {
                items.append(
                    ReasonCopy(
                        kind: .time,
                        english: "About \(remainingMinutes) minutes of play remain after this warm-in.",
                        russian: "После разминки впереди ещё около \(remainingMinutes) минут игры.",
                        icon: "clock.fill",
                        colorFamily: .ready
                    )
                )
            }
            items.append(
                ReasonCopy(
                    kind: .training,
                    english: "A calm warm-in keeps the legs fresher for later rallies.",
                    russian: "Спокойная разминка сохраняет ноги для розыгрышей позже.",
                    icon: "figure.tennis",
                    colorFamily: .ready
                )
            )
            return Array(items.prefix(2))

        case .findRhythm:
            return [
                ReasonCopy(
                    kind: .training,
                    english: "Rhythm on court matters more than chasing every point early.",
                    russian: "Ритм на корте важнее, чем гоняться за каждым очком в начале.",
                    icon: "figure.tennis",
                    colorFamily: .ready
                ),
                ReasonCopy(
                    kind: .time,
                    english: elapsedMinutes > 0
                        ? "You are \(elapsedMinutes) minutes in — settle timing and breathing."
                        : "Settle timing and breathing before pushing pace.",
                    russian: elapsedMinutes > 0
                        ? "Вы уже \(elapsedMinutes) минут в игре — настройте тайминг и дыхание."
                        : "Настройте тайминг и дыхание, прежде чем ускоряться.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
            ]

        case .manageLoad:
            var items: [ReasonCopy] = []
            if elapsedMinutes > 0 {
                items.append(
                    ReasonCopy(
                        kind: .time,
                        english: "You are \(elapsedMinutes) minutes into the session.",
                        russian: "Вы уже \(elapsedMinutes) минут в сессии.",
                        icon: "clock.fill",
                        colorFamily: .ready
                    )
                )
            }
            items.append(
                ReasonCopy(
                    kind: .training,
                    english: "Selective sprints beat chasing every rally.",
                    russian: "Выборочные ускорения лучше, чем гоняться за каждым розыгрышем.",
                    icon: "figure.tennis",
                    colorFamily: .activity
                )
            )
            return Array(items.prefix(2))

        case .closeSmart:
            return [
                ReasonCopy(
                    kind: .time,
                    english: remainingMinutes.map { "About \($0) minutes remain — close without overspending." } ?? "The end is near — close without overspending.",
                    russian: remainingMinutes.map { "Осталось около \($0) минут — закройте без перегиба." } ?? "Финал близко — закройте без перегиба.",
                    icon: "clock.fill",
                    colorFamily: .ready
                ),
                ReasonCopy(
                    kind: .constraint,
                    english: shouldProtectTomorrow
                        ? "What you spend now can cost tomorrow's session."
                        : "Last rallies should not drain the legs for the rest of today.",
                    russian: shouldProtectTomorrow
                        ? "То, что потратите сейчас, может стоить завтрашней сессии."
                        : "Последние розыгрыши не должны опустошить ноги на остаток дня.",
                    icon: "flag.checkered",
                    colorFamily: .warning
                )
            ]

        case .recoveryWindow:
            return [
                ReasonCopy(
                    kind: .recovery,
                    english: "The first hour after court work is the main recovery window.",
                    russian: "Первый час после корта — главное окно восстановления.",
                    icon: "bed.double.fill",
                    colorFamily: .recovery
                ),
                ReasonCopy(
                    kind: .hydration,
                    english: "Fluids and calm legs matter more than another session now.",
                    russian: "Вода и спокойные ноги важнее ещё одной сессии сейчас.",
                    icon: "drop.fill",
                    colorFamily: .hydration
                )
            ]

        case .fueling:
            return [
                ReasonCopy(
                    kind: .fuel,
                    english: "Energy is behind what court work demands.",
                    russian: "Энергии меньше, чем требует работа на корте.",
                    icon: "bolt.fill",
                    colorFamily: .fuel
                ),
                ReasonCopy(
                    kind: .time,
                    english: remainingMinutes.map { "Roughly \($0) minutes of play remain." } ?? "There is still play ahead.",
                    russian: remainingMinutes.map { "Примерно \($0) минут игры впереди." } ?? "Впереди ещё есть игра.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
            ]

        case .hydration:
            return [
                ReasonCopy(
                    kind: .hydration,
                    english: "Fluids are behind what court heat and effort need.",
                    russian: "Воды меньше, чем нужно для жары и нагрузки на корте.",
                    icon: "drop.fill",
                    colorFamily: .hydration
                ),
                ReasonCopy(
                    kind: .time,
                    english: remainingMinutes.map { "About \($0) minutes remain to correct this." } ?? "There is still time to top up.",
                    russian: remainingMinutes.map { "Ещё около \($0) минут, чтобы пополнить." } ?? "Ещё есть время пополнить.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
            ]

        case .postLong, .postMedium, .postShort:
            return [
                ReasonCopy(
                    kind: .recovery,
                    english: recoveryPercent >= 75
                        ? "Recovery looks good enough to keep the rest of the day calm."
                        : "Recovery is limited — keep the rest of the day easy.",
                    russian: recoveryPercent >= 75
                        ? "Восстановление позволяет держать остаток дня спокойно."
                        : "Восстановление ограничено — остаток дня лучше лёгкий.",
                    icon: "heart.fill",
                    colorFamily: .recovery
                )
            ]
        }
    }

    static func extras(
        for phase: Phase,
        activity: PlannedActivity?,
        longSession: Bool,
        minutesSinceEnd: Int
    ) -> [ActionCopy] {
        switch phase {
        case .recoveryWindow:
            return [
                action(
                    .rehydrateGradually,
                    "Drink 500-800 ml fluid",
                    "Over the next hour",
                    "Выпейте 500-800 мл воды",
                    "В течение следующего часа"
                )
            ]
        default:
            return []
        }
    }

    // MARK: - Warm In

    private static func warmInTennis(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Warm in before the rallies", "Разогрейтесь до первых розыгрышей"),
            assessment: bi(
                "The session just started — legs and timing need a few minutes before full pace.",
                "Сессия только началась — ногам и таймингу нужно несколько минут до полного темпа."
            ),
            situation: bi("First games are for rhythm, not for proving pace.", "Первые геймы — для ритма, а не для проверки скорости."),
            primary: action(
                .controlIntensity,
                "Keep the first games light",
                "Add pace when footwork feels settled",
                "Первые геймы держите легко",
                "Добавляйте темп, когда ноги и шаг стабильны"
            ),
            avoidance: bi(
                longSession ? "Do not spike intensity before the first long rallies." : "Do not sprint the first exchanges.",
                longSession ? "Не рваните интенсивность до первых длинных розыгрышей." : "Не рваните в первых обменах."
            ),
            extras: []
        )
    }

    private static func warmInSquash(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Warm in before the rallies", "Разогрейтесь до первых розыгрышей"),
            assessment: bi(
                "Squash starts fast — give hips and lungs a minute before full exchanges.",
                "Сквош начинается быстро — дайте бёдрам и лёгким минуту до полных обменов."
            ),
            situation: bi("Let the first rallies find length before chasing pace.", "Первые розыгрыши — для длины, а не для гонки темпа."),
            primary: action(
                .controlIntensity,
                "Keep the first rallies controlled",
                "Build pace when movement feels smooth",
                "Первые розыгрыши держите под контролем",
                "Наращивайте темп, когда движение становится плавным"
            ),
            avoidance: bi(
                "Do not chase every ball at full speed from the first serve.",
                "Не гонитесь за каждым мячом на полной скорости с первой подачи."
            ),
            extras: []
        )
    }

    private static func warmInGeneral(longSession: Bool) -> WindowCopy {
        warmInTennis(longSession: longSession)
    }

    // MARK: - Find Rhythm

    private static func findRhythmTennis(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Find your court rhythm", "Найдите ритм на корте"),
            assessment: bi(
                longSession
                    ? "The warm-in is done — timing and length matter more than raw pace now."
                    : "You are settling in — timing and breathing should lead the next block.",
                longSession
                    ? "Разминка позади — тайминг и длина важнее сырой скорости."
                    : "Вы входите в игру — тайминг и дыхание ведут следующий блок."
            ),
            situation: bi("Let rallies breathe — length before aggression.", "Дайте розыгрышам дышать — длина перед агрессией."),
            primary: action(
                .controlIntensity,
                "Focus on timing and footwork",
                "Speed up only when contact feels clean",
                "Держите тайминг и работу ног",
                "Ускоряйтесь, когда удар становится чистым"
            ),
            avoidance: bi(
                "Do not force winners before rhythm is there.",
                "Не гонитесь за выигрышными ударами, пока ритм не найден."
            ),
            extras: []
        )
    }

    private static func findRhythmSquash(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Find your court rhythm", "Найдите ритм на корте"),
            assessment: bi(
                "You are into the match — length and recovery steps matter more than raw speed.",
                "Вы в матче — длина и шаги восстановления важнее сырой скорости."
            ),
            situation: bi("T position and breathing before every chase.", "Позиция T и дыхание перед каждым преследованием."),
            primary: action(
                .controlIntensity,
                "Recover to centre after each rally",
                "Add pace only on chosen balls",
                "Возвращайтесь в центр после каждого розыгрыша",
                "Ускоряйтесь только на выбранных мячах"
            ),
            avoidance: bi(
                "Do not sprint every retrieval before rhythm settles.",
                "Не рваните на каждый мяч, пока ритм не стабилизируется."
            ),
            extras: []
        )
    }

    private static func findRhythmGeneral(longSession: Bool) -> WindowCopy {
        findRhythmTennis(longSession: longSession)
    }

    // MARK: - Manage Load

    private static func manageLoadTennis(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Choose your sprints", "Выбирайте рывки осознанно"),
            assessment: bi(
                longSession
                    ? "You are in the working middle — selective accelerations beat constant chase."
                    : "The middle is about choosing which rallies to invest in.",
                longSession
                    ? "Вы в рабочей середине — выборочные ускорения лучше постоянной гонки."
                    : "Середина — про выбор, в какие розыгрыши вкладываться."
            ),
            situation: bi("Sprint budget matters more than point count.", "Бюджет ускорений важнее счёта очков."),
            primary: action(
                .controlIntensity,
                "Cap repeated sprints",
                "Keep the hardest rallies selective",
                "Ограничьте повторные рывки",
                "Самые тяжёлые розыгрыши — выборочно"
            ),
            avoidance: bi(
                "Do not chase every deep ball just because legs still respond.",
                "Не гонитесь за каждым глубоким мячом только потому, что ноги ещё отвечают."
            ),
            extras: []
        )
    }

    private static func manageLoadSquash(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Choose your sprints", "Выбирайте рывки осознанно"),
            assessment: bi(
                "Court load stacks through repeated accelerations — pick your chases.",
                "Нагрузка на корте нарастает через ускорения — выбирайте преследования."
            ),
            situation: bi("Not every boast needs a full sprint.", "Не каждый boast требует полного рывка."),
            primary: action(
                .controlIntensity,
                "Let some balls go",
                "Save legs for rallies that matter",
                "Отпускайте часть мячей",
                "Берегите ноги для важных розыгрышей"
            ),
            avoidance: bi(
                "Do not turn every rally into a full-court sprint.",
                "Не превращайте каждый розыгрыш в спринт по всему корту."
            ),
            extras: []
        )
    }

    private static func manageLoadGeneral(longSession: Bool) -> WindowCopy {
        manageLoadTennis(longSession: longSession)
    }

    // MARK: - Close Smart

    private static func closeSmartTennis(longSession: Bool, remainingMinutes: Int?) -> WindowCopy {
        let remainingEN = remainingMinutes.map { "About \($0) minutes remain — " } ?? ""
        let remainingRU = remainingMinutes.map { "Осталось около \($0) минут — " } ?? ""
        return WindowCopy(
            hero: bi("Close the session smart", "Закройте сессию без перегиба"),
            assessment: bi(
                "\(remainingEN)last games should not drain tomorrow's legs.",
                "\(remainingRU)последние геймы не должны опустошить ноги на завтра."
            ),
            situation: bi("Smart closing beats one more heroic rally.", "Умное закрытие лучше, чем ещё один героический розыгрыш."),
            primary: action(
                .controlIntensity,
                "Hold selective intensity",
                "No extra sprints for pride",
                "Держите выборочную интенсивность",
                "Без лишних рывков ради азарта"
            ),
            avoidance: bi(
                longSession
                    ? "Do not spend the last half-hour chasing lost points."
                    : "Do not sprint the last games just because the finish is close.",
                longSession
                    ? "Не тратьте последние полчаса на отыгрывание очков."
                    : "Не рваните последние геймы только потому, что финал близко."
            ),
            extras: []
        )
    }

    private static func closeSmartSquash(longSession: Bool, remainingMinutes: Int?) -> WindowCopy {
        closeSmartTennis(longSession: longSession, remainingMinutes: remainingMinutes)
    }

    private static func closeSmartGeneral(longSession: Bool, remainingMinutes: Int?) -> WindowCopy {
        closeSmartTennis(longSession: longSession, remainingMinutes: remainingMinutes)
    }

    // MARK: - Recovery Window

    private static func recoveryWindow(sport: Modality) -> WindowCopy {
        let sportEN = sport == .squash ? "Squash" : "Court work"
        let sportRU = sport == .squash ? "Сквош" : "Работа на корте"
        return WindowCopy(
            hero: bi("Recovery window is open", "Окно восстановления открыто"),
            assessment: bi(
                "\(sportEN) is done — the next hour sets how the legs feel tonight.",
                "\(sportRU) позади — следующий час определяет, как чувствуются ноги вечером."
            ),
            situation: bi("Fluids, light food, and calm movement — not another hard block.", "Вода, лёгкая еда и спокойное движение — не ещё один тяжёлый блок."),
            primary: action(
                .recoveryMeal,
                "Eat and drink in the next hour",
                "Light protein and fluids for the legs",
                "Поешьте и попейте в ближайший час",
                "Лёгкий белок и вода для ног"
            ),
            avoidance: bi(
                "Do not add court intensity in the recovery window.",
                "Не добавляйте интенсивность на корте в окне восстановления."
            ),
            extras: []
        )
    }

    // MARK: - Deficit

    private static func fueling(sport: Modality) -> WindowCopy {
        WindowCopy(
            hero: bi("Refuel now", "Подкрепитесь сейчас"),
            assessment: bi(
                "Energy is behind what court work needs — a short snack helps now.",
                "Энергии меньше, чем нужно для работы на корте — короткий перекус сейчас поможет."
            ),
            situation: bi("A gel or banana beats pushing on empty.", "Гель или банан лучше, чем играть на пустом."),
            primary: action(
                .sustainEnergy,
                "Eat a quick snack now",
                "Before the next demanding rally block",
                "Съешьте быстрый перекус сейчас",
                "Перед следующим требовательным блоком розыгрышей"
            ),
            avoidance: bi(
                "Do not wait until legs feel empty.",
                "Не ждите, пока ноги «опустошатся»."
            ),
            extras: []
        )
    }

    private static func hydration(sport: Modality) -> WindowCopy {
        WindowCopy(
            hero: bi("Top up fluids on court", "Пополните воду на корте"),
            assessment: bi(
                "Fluids are behind — court heat and effort make this urgent.",
                "Воды не хватает — жара и нагрузка на корте делают это срочным."
            ),
            situation: bi("Sip steadily between games — not all at once.", "Пейте понемногу между геймами — не залпом."),
            primary: action(
                .rehydrateGradually,
                "Drink 300-500 ml now",
                "Over the next 15-20 minutes",
                "Выпейте 300-500 мл сейчас",
                "В течение 15-20 минут"
            ),
            avoidance: bi(
                "Do not play dehydrated just because the set is close.",
                "Не играйте обезвоженным только потому, что сет близко."
            ),
            extras: []
        )
    }

    // MARK: - Post (non-recovery-window)

    private static func postLong(
        timing: PostTiming,
        context: PostContext?,
        sport: Modality
    ) -> WindowCopy {
        let sportEN = sport == .squash ? "Squash" : "Court session"
        let sportRU = sport == .squash ? "Сквош" : "Сессия на корте"
        if timing == .stale {
            return WindowCopy(
                hero: bi("Court work is behind you", "\(sportRU) позади"),
                assessment: bi("The session ended a while ago — calm evening matters now.", "Сессия закончилась давно — сейчас важен спокойный вечер."),
                situation: bi("Recovery is mostly about sleep and calm now.", "Восстановление сейчас — в сон и спокойствие."),
                primary: action(.sleepPriority, "Keep the evening calm", "No extra load tonight", "Вечер держите спокойным", "Без лишней нагрузки вечером"),
                avoidance: bi("Do not add another hard session tonight.", "Не добавляйте ещё одну тяжёлую сессию вечером."),
                extras: []
            )
        }
        return WindowCopy(
            hero: bi("\(sportEN) behind you", "\(sportRU) позади"),
            assessment: bi("Legs need fluids and calm — protect the rest of the day.", "Ногам нужны вода и покой — берегите остаток дня."),
            situation: bi("Recovery leads the rest of today.", "Дальше ведёт восстановление."),
            primary: action(.rehydrateGradually, "Drink steadily", "Over the next hour", "Пейте понемногу", "В течение следующего часа"),
            avoidance: bi("Do not chase another hard block today.", "Не гонитесь за ещё одним тяжёлым блоком сегодня."),
            extras: []
        )
    }

    private static func postMedium(timing: PostTiming, context: PostContext?, sport: Modality) -> WindowCopy {
        postLong(timing: timing, context: context, sport: sport)
    }

    private static func postShort(timing: PostTiming, context: PostContext?, sport: Modality) -> WindowCopy {
        postLong(timing: timing, context: context, sport: sport)
    }

    // MARK: - Helpers

    private static func bi(_ english: String, _ russian: String) -> BilingualText {
        BilingualText(english: english, russian: russian)
    }

    private static func action(
        _ type: CoachSupportActionTypeV3,
        _ titleEN: String,
        _ subtitleEN: String,
        _ titleRU: String,
        _ subtitleRU: String
    ) -> ActionCopy {
        ActionCopy(
            type: type,
            title: bi(titleEN, titleRU),
            subtitle: bi(subtitleEN, subtitleRU)
        )
    }
}
