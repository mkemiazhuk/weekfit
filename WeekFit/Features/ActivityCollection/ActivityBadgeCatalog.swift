import Foundation

enum ActivityBadgeCategory: String, Codable, CaseIterable {
    case activity
    case recovery
    case habit
}

enum ActivityBadgeRequirement: String, Codable {
    /// First completed or correctly logged session of this type.
    case completedSession
    /// Breathing counts only after a full minute.
    case breathingMinute
    /// Daily water goal reached once. Planning the habit does not count.
    case waterGoal
    /// First check-in. Creating or scheduling the habit does not count.
    case habitCheckIn
}

struct ActivityBadgeDefinition: Equatable, Identifiable {
    let id: String
    let category: ActivityBadgeCategory
    let catalogTitle: String
    let symbol: String
    let nameEN: String
    let nameRU: String
    let conditionEN: String
    let conditionRU: String
    let actionEN: String
    let actionRU: String
    let actionMinutes: Int?
    let requirement: ActivityBadgeRequirement
    /// Can be started right now, without extra setup. Used for Today and the nudge.
    let startsImmediately: Bool

    func name(russian: Bool) -> String { russian ? nameRU : nameEN }
    func condition(russian: Bool) -> String { russian ? conditionRU : conditionEN }
    func action(russian: Bool) -> String { russian ? actionRU : actionEN }
}

enum ActivityBadgeCatalog {
    static let definitions: [ActivityBadgeDefinition] = [
        def("activity.cycling", .activity, "Cycling", "figure.outdoor.cycle", "Two Wheels", "На двух колёсах", "First completed ride", "Первая завершённая поездка", "Ride", "Поехать", 45, .completedSession, false),
        def("activity.running", .activity, "Running", "figure.run", "First Run", "Первый забег", "First completed run", "Первый завершённый забег", "Run", "Побежать", 45, .completedSession, false),
        def("activity.swimming", .activity, "Swimming", "figure.pool.swim", "First Length", "Первая длина", "First completed swim", "Первое завершённое плавание", "Swim", "Поплавать", 45, .completedSession, false),
        def("activity.hiking", .activity, "Hiking", "figure.hiking", "First Trail", "Первая тропа", "First completed hike", "Первый завершённый поход", "Hike", "Пойти в поход", 45, .completedSession, false),
        def("activity.snowboarding", .activity, "Snowboarding", "figure.snowboarding", "First Ride", "Первый проезд", "First completed snowboard session", "Первый завершённый спуск на сноуборде", "Snowboard", "Встать на сноуборд", 45, .completedSession, false),
        def("activity.alpine-skiing", .activity, "Alpine Skiing", "figure.skiing.downhill", "First Descent", "Первый спуск", "First completed ski session", "Первый завершённый спуск на лыжах", "Ski", "Встать на лыжи", 45, .completedSession, false),
        def("activity.upper-body", .activity, "Upper Body", "dumbbell.fill", "Upper Start", "Первый верх", "First completed upper-body session", "Первая завершённая тренировка верха", "Train upper body", "Тренировать верх", 45, .completedSession, false),
        def("activity.core", .activity, "Core", "figure.core.training", "Core Start", "Первый пресс", "First completed core session", "Первая завершённая тренировка пресса", "Train core", "Тренировать пресс", 45, .completedSession, false),
        def("activity.lower-body", .activity, "Lower Body", "figure.strengthtraining.traditional", "Lower Start", "Первый низ", "First completed lower-body session", "Первая завершённая тренировка низа", "Train lower body", "Тренировать низ", 45, .completedSession, false),
        def("activity.full-body", .activity, "Full Body", "figure.strengthtraining.functional", "Full Effort", "Всё тело", "First completed full-body session", "Первая завершённая тренировка всего тела", "Train full body", "Тренировать всё тело", 45, .completedSession, false),
        def("activity.tennis", .activity, "Tennis", "figure.tennis", "First Serve", "Первая подача", "First completed tennis session", "Первый завершённый теннис", "Play tennis", "Сыграть в теннис", 45, .completedSession, false),
        def("activity.padel", .activity, "Padel", "figure.tennis", "First Rally", "Первый розыгрыш", "First completed padel session", "Первый завершённый падел", "Play padel", "Сыграть в падел", 45, .completedSession, false),
        def("activity.squash", .activity, "Squash", "figure.squash", "First Point", "Первое очко", "First completed squash session", "Первый завершённый сквош", "Play squash", "Сыграть в сквош", 45, .completedSession, false),
        def("activity.hiit", .activity, "High Intensity Interval Training", "figure.highintensity.intervaltraining", "First Interval", "Первый интервал", "First completed interval session", "Первая завершённая интервальная тренировка", "Start intervals", "Начать интервалы", 45, .completedSession, false),

        def("recovery.stretching", .recovery, "Stretching", "figure.cooldown", "Stretch Break", "Пауза на растяжку", "First completed stretch", "Первая завершённая растяжка", "Stretch", "Потянуться", 20, .completedSession, false),
        def("recovery.walk", .recovery, "Walk", "figure.walk", "First Steps", "Первые шаги", "First completed walk. Steps alone do not count", "Первая завершённая прогулка. Шаги сами по себе не считаются", "Take a short walk", "Короткая прогулка", 20, .completedSession, true),
        def("recovery.sauna", .recovery, "Sauna", "flame.fill", "Sauna Reset", "Время согреться", "First completed sauna", "Первая завершённая сауна", "Sauna", "Сауна", 20, .completedSession, false),
        def("recovery.yoga", .recovery, "Yoga", "figure.yoga", "On the Mat", "На коврике", "First completed yoga session", "Первая завершённая йога", "Yoga", "Йога", 20, .completedSession, false),
        def("recovery.breathing", .recovery, "Breathing", "wind", "First Pause", "Первая пауза", "A full minute of breathing", "Полная минута дыхания", "Take a minute to breathe", "Минута дыхания", 1, .breathingMinute, true),

        def("habit.drink-water", .habit, "Drink Water", "drop.fill", "First Glass", "Первый стакан", "Reach the daily water goal once", "Один раз закрыть дневную цель по воде", "Log a glass of water", "Записать стакан воды", nil, .waterGoal, true),
        def("habit.sleep-routine", .habit, "Sleep Routine", "moon.stars.fill", "Lights Down", "Пора гасить", "First check-in of the sleep routine", "Первая отметка вечернего ритуала", "Check in", "Отметить", nil, .habitCheckIn, false),
        def("habit.no-screens", .habit, "No Screens", "iphone.slash", "Screen Break", "Без экрана", "First check-in without screens", "Первая отметка без экрана", "Check in", "Отметить", nil, .habitCheckIn, false),
        def("habit.morning-routine", .habit, "Morning Routine", "sun.max.fill", "Morning Mark", "Утренняя отметка", "First check-in of the morning routine", "Первая отметка утренних дел", "Check in", "Отметить", nil, .habitCheckIn, false)
    ]

    static let customAchievementEN = "First Check-in"
    static let customAchievementRU = "Первая отметка"
    static let customConditionEN = "First time this habit is checked in"
    static let customConditionRU = "Первая отметка этой привычки"

    /// Apple Health titles that are the same activity under another name.
    static let healthTitleAliases: [String: String] = [
        "HIIT Workout": "High Intensity Interval Training",
        "Core Training": "Core"
    ]

    static func definition(id: String) -> ActivityBadgeDefinition? {
        definitions.first { $0.id == id }
    }

    static func definition(catalogTitle: String) -> ActivityBadgeDefinition? {
        let key = normalize(catalogTitle)
        return definitions.first { normalize($0.catalogTitle) == key }
    }

    static func canonicalCatalogTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = definition(catalogTitle: trimmed) {
            return direct.catalogTitle
        }
        if let alias = healthTitleAliases[trimmed] {
            return alias
        }
        let folded = normalize(trimmed)
        return healthTitleAliases.first { normalize($0.key) == folded }?.value
    }

    static func normalize(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func def(
        _ id: String,
        _ category: ActivityBadgeCategory,
        _ catalogTitle: String,
        _ symbol: String,
        _ nameEN: String,
        _ nameRU: String,
        _ conditionEN: String,
        _ conditionRU: String,
        _ actionEN: String,
        _ actionRU: String,
        _ minutes: Int?,
        _ requirement: ActivityBadgeRequirement,
        _ startsImmediately: Bool
    ) -> ActivityBadgeDefinition {
        ActivityBadgeDefinition(
            id: id,
            category: category,
            catalogTitle: catalogTitle,
            symbol: symbol,
            nameEN: nameEN,
            nameRU: nameRU,
            conditionEN: conditionEN,
            conditionRU: conditionRU,
            actionEN: actionEN,
            actionRU: actionRU,
            actionMinutes: minutes,
            requirement: requirement,
            startsImmediately: startsImmediately
        )
    }
}
