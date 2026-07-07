import Foundation

/// Time-of-day aware fuel / hydration copy — shared across CopyRegistry scenarios.
enum CoachCopyNutritionTiming {

    /// After ~21:00 — no full-meal advice; sleep and tomorrow's breakfast matter more.
    static func isWindDown(_ timeOfDay: CoachTimeOfDay) -> Bool {
        timeOfDay == .lateEvening || timeOfDay == .night
    }

    /// After 23:00 — the day is over; copy should say sleep now, not plan a ritual.
    static func isSleepNow(_ timeOfDay: CoachTimeOfDay) -> Bool {
        CoachTimeOfDay.isSleepNow(timeOfDay)
    }

    /// Regular daytime / early evening — normal meal guidance is still appropriate.
    static func isMealWindowOpen(_ timeOfDay: CoachTimeOfDay) -> Bool {
        !isWindDown(timeOfDay)
    }

    // MARK: - Supporting signals

    static func fuelBehindSignal(for input: CoachCopyBuildInput) -> CoachBilingualText {
        if isWindDown(input.timeOfDay) {
            return .en(
                "Calories lag today's load.",
                "Калорий маловато для такого дня."
            )
        }
        return .en(
            "Fuel intake is lagging the day so far.",
            "Еды пока меньше, чем требует день."
        )
    }

    static func hydrationBehindSignal(for input: CoachCopyBuildInput) -> CoachBilingualText {
        if isWindDown(input.timeOfDay) {
            return .en(
                "Water still behind.",
                "Воды пока не хватает."
            )
        }
        return .en(
            "Water is running behind today.",
            "Воды за день пока маловато."
        )
    }

    /// Neutral fasting-window context — not a deficit warning.
    static func firstMealAheadSignal() -> CoachBilingualText {
        .en(
            "First meal is still ahead.",
            "Первый приём пищи ещё впереди"
        )
    }

    // MARK: - Next actions

    static func fuelCatchUpNextAction(for input: CoachCopyBuildInput) -> CoachBilingualText {
        if isMealWindowOpen(input.timeOfDay) {
            return .en(
                "Eat a proper meal before the day winds down.",
                "Нормально поешьте, пока не поздно."
            )
        }
        return .en(
            "Plan a solid breakfast before the session.",
            "Запланируйте нормальный завтрак перед тренировкой."
        )
    }

    static func hydrationCatchUpNextAction(for input: CoachCopyBuildInput) -> CoachBilingualText {
        if isWindDown(input.timeOfDay) {
            return .en(
                "Sip if thirsty, then wind down.",
                "Если хочется пить — немного воды."
            )
        }
        return .en(
            "Drink a glass of water in the next hour.",
            "Стакан воды в ближайший час — будет кстати."
        )
    }

    static func fastingAwareRecoveryNextAction(mealWindowOpen: Bool) -> CoachBilingualText {
        if mealWindowOpen {
            return .en(
                "Stretch or walk briefly, then eat when hungry.",
                "Растяжка или прогулка — еда, когда проголодаетесь."
            )
        }
        return .en(
            "Water by feel — first meal at your usual time.",
            "Вода по самочувствию, первый приём пищи — в привычное время."
        )
    }

    static func windDownSleepNextAction() -> CoachBilingualText {
        .en(
            "Pick a bedtime and stick to it.",
            "Решите, во сколько ложитесь — и придерживайтесь."
        )
    }

    // MARK: - Critical warnings (active session only)

    static func fuelCriticalWarning(isActiveSession: Bool) -> CoachBilingualText {
        if isActiveSession {
            return .en(
                "Running low on fuel for this session — eat now.",
                "На тренировке не хватает энергии — поешьте."
            )
        }
        return .en(
            "Fuel is critically low — don't start hard work until you've eaten.",
            "Слишком мало еды — тяжёлую работу лучше не начинать."
        )
    }

    static func hydrationCriticalWarning(
        isActiveSession: Bool,
        timeOfDay: CoachTimeOfDay
    ) -> CoachBilingualText {
        if isActiveSession {
            return .en(
                "Fluids are critically low — sip now, steadily.",
                "Очень мало жидкости — пейте понемногу, но сейчас."
            )
        }
        if isWindDown(timeOfDay) {
            return .en(
                "Fluids are very low — small sips if thirsty, then wind down.",
                "Жидкости мало — немного воды, если хочется, и отдых."
            )
        }
        return .en(
            "Fluids are critically low — sip now, steadily.",
            "Очень мало жидкости — пейте понемногу, но сейчас."
        )
    }
}
