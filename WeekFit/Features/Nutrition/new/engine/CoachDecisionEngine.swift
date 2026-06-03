import Foundation

struct CoachDecision {
    let primaryStrategy: PrimaryStrategy
    let secondaryPriorities: [CoachPriority]
    let suppressedActions: Set<CoachSuppression>

    let hydrationAlreadySolved: Bool
    let needsElectrolytesInsteadOfWater: Bool

    var suppressHydrationAdvice: Bool {
        suppressedActions.contains(.hydration)
    }

    var suppressWorkoutPush: Bool {
        suppressedActions.contains(.workoutPush)
    }

    var suppressHeavyFoodAdvice: Bool {
        suppressedActions.contains(.heavyFood)
    }
}

enum PrimaryStrategy {
    case logFood
    case protectRecovery
    case prepareWorkout
    case rehydrate
    case refuel
    case addProtein
    case maintain
    case overload
    case supercompensation // ✅ ИСПРАВЛЕНО: Новый режим для сверхвысокой активности при хорошем сне
}

enum CoachPriority: Hashable {
    case hydration
    case protein
    case carbs
    case recovery
    case sleep
    case minerals
    case schedule
}

enum CoachSuppression: Hashable {
    case hydration
    case workoutPush
    case heavyFood
    case fastCarbs
}

enum CoachDecisionEngine {

    static func makeDecision(
        from brain: HumanBrain.State
    ) -> CoachDecision {

        let hydrationAlreadySolved =
            brain.hydration == .completed ||
            brain.hydration == .excessive

        let needsElectrolytesInsteadOfWater =
            brain.hydration == .excessive ||
            brain.current.waterProgress >= 1.15

        let primary = primaryStrategy(for: brain)

        let secondary = secondaryPriorities(
            for: brain,
            primary: primary
        )

        // ✅ ИСПРАВЛЕНО: Добавлен пропущенный аргумент primary: primary
        let suppressed = suppressedActions(
            for: brain,
            primary: primary,
            hydrationAlreadySolved: hydrationAlreadySolved,
            needsElectrolytesInsteadOfWater: needsElectrolytesInsteadOfWater
        )

        return CoachDecision(
            primaryStrategy: primary,
            secondaryPriorities: secondary,
            suppressedActions: suppressed,
            hydrationAlreadySolved: hydrationAlreadySolved,
            needsElectrolytesInsteadOfWater: needsElectrolytesInsteadOfWater
        )
    }
}

private extension CoachDecisionEngine {

    static func primaryStrategy(
        for brain: HumanBrain.State
    ) -> PrimaryStrategy {

        // 🚀 ДОБАВЛЯЕМ ЛОГ В ДВИЖОК:
//        print("""
//        🤖 [ENGINE EVALUATION]
//        - energyCoverage: \(brain.current.energyCoverage)
//        - carbsProgress: \(brain.current.carbsProgress)
//        - fuel state: \(brain.fuel)
//        - strain state: \(brain.strain)
//        """)


        let isHighStrain = brain.strain == .high || brain.strain == .veryHigh
        let calorieLimit = isHighStrain ? 1.40 : 1.15
        
        let isTotalCaloriesOverflown = brain.current.energyCoverage > calorieLimit
        let isCarbsSeverelyOverflown = brain.current.carbsProgress >= 1.30
        
        if isTotalCaloriesOverflown || isCarbsSeverelyOverflown {
            return .overload
        }

        if !brain.hasAnyFoodLogged {

            if shouldStayInMorningBaseline(brain) {
                return .maintain
            }

            if brain.future.hasWorkoutSoon {
                return .prepareWorkout
            }

            if shouldPrioritizeHydration(brain) {
                return .rehydrate
            }

            if brain.protein == .low &&
                brain.currentHour >= 13 {
                return .addProtein
            }

            return .maintain
        }

        // 2. Метаболическое утомление (Твои 442% активности при 58% еды)
        // Теперь $1.1531 < 1.40$, оверлоад пролетает мимо, и мы гарантированно заходим сюда!
        if isStrainExtremelyHigh(brain) {
            return .supercompensation
        }

        if isRecoveryCompromised(brain) {
            return .protectRecovery
        }

        if isSeverelyUnderfueled(brain) {
            return .refuel
        }

        if shouldPrepareWorkout(brain) {
            return .prepareWorkout
        }

        if isEveningFuelPriority(brain) {
            return .refuel
        }

        if isEveningProteinPriority(brain) {
            return .addProtein
        }

        if shouldPrioritizeHydration(brain) {
            return .rehydrate
        }

        if brain.fuel == .underfueled &&
            (brain.strain == .high || brain.strain == .veryHigh) {
            return .refuel
        }

        if brain.protein == .low ||
            brain.protein == .behind {
            return .addProtein
        }

        if brain.fuel == .light &&
            brain.current.energyCoverage < 0.45 {
            return .refuel
        }

        return .maintain
    }
    
    static func shouldStayInMorningBaseline(
        _ brain: HumanBrain.State
    ) -> Bool {

        guard !brain.hasAnyFoodLogged else {
            return false
        }

        guard brain.currentHour < 12 else {
            return false
        }

        if brain.future.hasWorkoutSoon {
            return false
        }

        return true
    }

    static func secondaryPriorities(
        for brain: HumanBrain.State,
        primary: PrimaryStrategy
    ) -> [CoachPriority] {

        var priorities: [CoachPriority] = []

        func add(_ priority: CoachPriority) {
            guard !priorities.contains(priority) else { return }
            priorities.append(priority)
        }

        if primary == .overload {
            add(.recovery)
            add(.sleep)
            return priorities
        }

        // Настройка приоритетов для режима сверхнагрузки
        if primary == .supercompensation {
            add(.recovery)
            add(.protein)
            add(.sleep)
            return priorities
        }

        if brain.recovery == .vulnerable ||
            brain.recovery == .compromised ||
            brain.readiness == .low ||
            brain.readiness == .compromised {
            add(.recovery)
        }

        if brain.protein == .low ||
            brain.protein == .behind {
            add(.protein)
        }

        if brain.fuel == .underfueled ||
            brain.fuel == .light ||
            brain.future.hasWorkoutSoon {
            add(.carbs)
        }

        if brain.hydration == .depleted ||
            brain.hydration == .behind {
            add(.hydration)
        }

        if brain.hydration == .excessive ||
            brain.current.waterProgress >= 1.15 {
            add(.minerals)
        }

        if brain.sleep == .short ||
            brain.sleep == .veryShort {
            add(.sleep)
        }

        switch primary {
        case .protectRecovery:
            add(.recovery)
            add(.protein)

        case .refuel:
            add(.protein)
            add(.carbs)
            add(.recovery)

        case .prepareWorkout:
            add(.carbs)

        case .rehydrate:
            add(.hydration)

        case .addProtein:
            add(.protein)
            add(.recovery)

        case .logFood:
            add(.protein)
            add(.carbs)

        case .maintain, .overload, .supercompensation:
            break
        }

        return priorities
    }

    static func suppressedActions(
            for brain: HumanBrain.State,
            primary: PrimaryStrategy, // 🚀 ДОБАВИЛИ В ПАРАМЕТРЫ
            hydrationAlreadySolved: Bool,
            needsElectrolytesInsteadOfWater: Bool
        ) -> Set<CoachSuppression> {

            var suppressed = Set<CoachSuppression>()

            if hydrationAlreadySolved ||
                brain.current.waterProgress >= 1.0 {
                suppressed.insert(.hydration)
            }

            if isRecoveryCompromised(brain) ||
                sleepRiskForWorkout(brain) ||
                brain.strain == .veryHigh {
                suppressed.insert(.workoutPush)
            }

            let isRealEnergyOverload = brain.current.energyCoverage > 1.15 || brain.current.carbsProgress >= 1.30
            
            // ✅ ТЕПЕРЬ РАБОТАЕТ: primary успешно найден в scope!
            // Ночью блокируем тяжелую еду только если это обычный день.
            // Если у пользователя режим .supercompensation — даем зеленый свет ночным белкам.
            let shouldSuppressHeavyFood = (brain.current.isLateNight && primary != .supercompensation) ||
                                          isRealEnergyOverload ||
                                          brain.recovery == .compromised
            
            if shouldSuppressHeavyFood {
                suppressed.insert(.heavyFood)
                suppressed.insert(.fastCarbs)
            }

            if needsElectrolytesInsteadOfWater {
                suppressed.insert(.hydration)
            }

            return suppressed
        }
}

// MARK: - Pure Physiology Helpers

private extension CoachDecisionEngine {

    // ✅ ИСПРАВЛЕНО: Специфический нутрициологический триггер мышечного истощения
    static func isStrainExtremelyHigh(
        _ brain: HumanBrain.State
    ) -> Bool {
        // Если активность по калориям превысила норму в 2.5 раза (твои 439%) ИЛИ тренировка длилась более 3 часов
        let hasExtremeCaloricStrain = brain.current.energyCoverage >= 2.50
        let isStrainVeryHigh = brain.strain == .veryHigh
        
        return hasExtremeCaloricStrain || isStrainVeryHigh
    }

    // Возвращено к чистым показателям дефицита сна/HRV без примесей калорий активности
    static func isRecoveryCompromised(
        _ brain: HumanBrain.State
    ) -> Bool {
        brain.recovery == .compromised ||
        brain.readiness == .compromised
    }

    static func isSeverelyUnderfueled(
        _ brain: HumanBrain.State
    ) -> Bool {
        let highLoad =
            brain.strain == .high ||
            brain.strain == .veryHigh

        return highLoad &&
        (
            brain.fuel == .underfueled ||
            brain.current.energyCoverage < 0.55
        )
    }

    static func shouldPrepareWorkout(
        _ brain: HumanBrain.State
    ) -> Bool {
        brain.future.hasWorkoutSoon &&
        brain.fuel == .underfueled &&
        !isRecoveryCompromised(brain)
    }

    static func isEveningFuelPriority(
        _ brain: HumanBrain.State
    ) -> Bool {
        guard brain.currentHour >= 15 else { return false }
        guard !isRecoveryCompromised(brain) else { return false }

        if brain.strain == .high ||
            brain.strain == .veryHigh {
            return brain.fuel == .underfueled ||
            brain.fuel == .light ||
            brain.current.energyCoverage < 0.70
        }

        return brain.fuel == .underfueled &&
        brain.current.energyCoverage < 0.40
    }

    static func isEveningProteinPriority(
        _ brain: HumanBrain.State
    ) -> Bool {
        guard brain.currentHour >= 15 else { return false }
        guard !isRecoveryCompromised(brain) else { return false }

        return brain.protein == .low ||
        brain.protein == .behind
    }

    static func shouldPrioritizeHydration(
        _ brain: HumanBrain.State
    ) -> Bool {

        guard brain.hydration == .depleted ||
                brain.hydration == .behind else {
            return false
        }

        if brain.current.waterProgress < 0.25 {
            return brain.currentHour < 15 ||
            (
                brain.protein == .good &&
                brain.fuel == .good
            )
        }

        if brain.currentHour >= 15 &&
            (
                brain.fuel == .underfueled ||
                brain.fuel == .light ||
                brain.protein == .low ||
                brain.protein == .behind
            ) {
            return false
        }

        return true
    }

    static func sleepRiskForWorkout(
        _ brain: HumanBrain.State
    ) -> Bool {
        brain.readiness == .low &&
        (
            brain.strain == .high ||
            brain.strain == .veryHigh
        )
    }
}
