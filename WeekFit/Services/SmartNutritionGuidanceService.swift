//import Foundation
//import SwiftUI
//import SwiftData
//
//@MainActor
//final class SmartNutritionGuidanceService {
//
//    private let repository = NutritionRepository()
//    private let healthManager: HealthManager
//    private let modelContext: ModelContext
//    private let classifier = ActivityNutritionClassifier()
//
//    init(
//        healthManager: HealthManager,
//        modelContext: ModelContext
//    ) {
//        self.healthManager = healthManager
//        self.modelContext = modelContext
//    }
//
//    func generateGuidance() -> [NutritionGuidanceItem] {
//        let meals = repository.loadMeals()
//        let activities = fetchTodayActivities()
//        let context = buildDayContext(from: activities)
//
//        var candidates: [GuidanceCandidate] = []
//
//        candidates.append(contentsOf: buildPrimaryDayGuidance(context: context, meals: meals))
//        candidates.append(contentsOf: buildActivityTimingGuidance(context: context, meals: meals))
//        candidates.append(contentsOf: buildRecoveryGuidance(context: context, meals: meals))
//        candidates.append(contentsOf: buildHydrationGuidance(context: context, meals: meals))
//        candidates.append(contentsOf: buildMealBalanceGuidance(context: context, meals: meals))
//
//        let uniqueItems = candidates
//            .sorted { $0.priority > $1.priority }
//            .reduce(into: [NutritionGuidanceItem]()) { result, candidate in
//                guard !result.contains(where: { $0.title == candidate.item.title }) else { return }
//                result.append(candidate.item)
//            }
//
//        if uniqueItems.isEmpty {
//            return [balancedDefaultGuidance(meals: meals)]
//        }
//
//        return Array(uniqueItems.prefix(3))
//    }
//
//    private func buildPrimaryDayGuidance(
//        context: DayNutritionContext,
//        meals: [Meals]
//    ) -> [GuidanceCandidate] {
//        var result: [GuidanceCandidate] = []
//
//        if context.hasSauna && context.hasWalk {
//            result.append(
//                GuidanceCandidate(
//                    priority: 100,
//                    item: NutritionGuidanceItem(
//                        title: "Recovery day",
//                        message: "Walk and sauna increase fluid needs today. Drink water before sauna and choose a light recovery meal after.",
//                        triggerLabel: "Walk + sauna today",
//                        icon: "drop.fill",
//                        color: blue,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.hydration, .recovery, .balanced]),
//                        suggestedTypes: [.hydration, .recovery, .balanced]
//                    )
//                )
//            )
//            return result
//        }
//
//        if context.hasSauna {
//            result.append(
//                GuidanceCandidate(
//                    priority: 95,
//                    item: NutritionGuidanceItem(
//                        title: "Prepare for sauna",
//                        message: "Sauna increases fluid loss. Drink water before it and avoid heavy meals close to the session.",
//                        triggerLabel: "Sauna today",
//                        icon: "drop.fill",
//                        color: blue,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.hydration, .recovery, .balanced]),
//                        suggestedTypes: [.hydration, .recovery, .balanced]
//                    )
//                )
//            )
//        }
//
//        if context.hasWorkout && context.lowBodyState {
//            result.append(
//                GuidanceCandidate(
//                    priority: 90,
//                    item: NutritionGuidanceItem(
//                        title: "Train lighter today",
//                        message: "Recovery looks lower today. Add carbs and water before training, then protein after.",
//                        triggerLabel: "Workout + low recovery",
//                        icon: "bolt.fill",
//                        color: orange,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.balanced, .recovery, .highProtein]),
//                        suggestedTypes: [.balanced, .recovery, .highProtein]
//                    )
//                )
//            )
//        } else if context.hasWorkout {
//            result.append(
//                GuidanceCandidate(
//                    priority: 80,
//                    item: NutritionGuidanceItem(
//                        title: "Fuel your workout",
//                        message: "Add slow carbs before activity and protein after to support recovery.",
//                        triggerLabel: "Workout today",
//                        icon: "flame.fill",
//                        color: orange,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.preWorkout, .highProtein, .balanced]),
//                        suggestedTypes: [.preWorkout, .highProtein, .balanced]
//                    )
//                )
//            )
//        }
//
//        if context.hasWalk && context.lowBodyState && !context.hasSauna {
//            result.append(
//                GuidanceCandidate(
//                    priority: 75,
//                    item: NutritionGuidanceItem(
//                        title: "Light recovery support",
//                        message: "A walk is a good low-impact choice today. Keep meals light and add protein with water.",
//                        triggerLabel: "Walk + recovery focus",
//                        icon: "leaf.fill",
//                        color: green,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.recovery, .balanced, .antiInflammatory]),
//                        suggestedTypes: [.recovery, .balanced, .antiInflammatory]
//                    )
//                )
//            )
//        }
//
//        return result
//    }
//
//    private func buildActivityTimingGuidance(
//        context: DayNutritionContext,
//        meals: [Meals]
//    ) -> [GuidanceCandidate] {
//        guard let next = context.nextActivity else { return [] }
//
//        let profile = classifier.profile(for: next)
//        let category = category(for: profile)
//
//        switch category {
//        case .sauna:
//            return [
//                GuidanceCandidate(
//                    priority: 85,
//                    item: NutritionGuidanceItem(
//                        title: "Prepare for sauna",
//                        message: "Drink water before sauna and avoid a heavy meal right before it. Restore fluids after.",
//                        triggerLabel: "Sauna at \(timeString(next.date))",
//                        icon: "drop.fill",
//                        color: blue,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.hydration, .balanced, .recovery]),
//                        suggestedTypes: [.hydration, .balanced, .recovery]
//                    )
//                )
//            ]
//
//        case .walk:
//            return [
//                GuidanceCandidate(
//                    priority: 65,
//                    item: NutritionGuidanceItem(
//                        title: "Fuel for your walk",
//                        message: "You do not need a heavy meal before a light walk. Drink water and eat if energy feels low.",
//                        triggerLabel: "Walk at \(timeString(next.date))",
//                        icon: "figure.walk",
//                        color: green,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.balanced, .hydration, .recovery]),
//                        suggestedTypes: [.balanced, .hydration, .recovery]
//                    )
//                )
//            ]
//
//        case .workout:
//            return [
//                GuidanceCandidate(
//                    priority: 70,
//                    item: NutritionGuidanceItem(
//                        title: "Pre-workout fuel",
//                        message: "Add easy carbs and water before activity. Choose protein after for muscle recovery.",
//                        triggerLabel: "\(profile.title) at \(timeString(next.date))",
//                        icon: profile.icon,
//                        color: profile.color,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.preWorkout, .balanced, .highProtein]),
//                        suggestedTypes: [.preWorkout, .balanced, .highProtein]
//                    )
//                )
//            ]
//
//        case .meal:
//            return []
//
//        case .recovery:
//            return [
//                GuidanceCandidate(
//                    priority: 55,
//                    item: NutritionGuidanceItem(
//                        title: "Keep recovery gentle",
//                        message: "Your next activity is recovery-focused. Choose light meals, water and easy protein.",
//                        triggerLabel: "\(profile.title) at \(timeString(next.date))",
//                        icon: "leaf.fill",
//                        color: green,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.recovery, .antiInflammatory, .balanced]),
//                        suggestedTypes: [.recovery, .antiInflammatory, .balanced]
//                    )
//                )
//            ]
//
//        case .other:
//            return []
//        }
//    }
//
//    private func buildRecoveryGuidance(
//        context: DayNutritionContext,
//        meals: [Meals]
//    ) -> [GuidanceCandidate] {
//        var result: [GuidanceCandidate] = []
//
//        if context.lowBodyState {
//            result.append(
//                GuidanceCandidate(
//                    priority: context.hasSauna ? 70 : 88,
//                    item: NutritionGuidanceItem(
//                        title: "Recovery focus today",
//                        message: "Sleep or readiness looks lower today. Choose lighter meals, enough water and recovery foods.",
//                        triggerLabel: "Low sleep or readiness",
//                        icon: "moon.fill",
//                        color: purple,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.recovery, .hydration, .antiInflammatory]),
//                        suggestedTypes: [.recovery, .hydration, .antiInflammatory]
//                    )
//                )
//            )
//        }
//
//        if let completed = context.lastDemandingCompletedActivity {
//            let profile = classifier.profile(for: completed)
//
//            result.append(
//                GuidanceCandidate(
//                    priority: 78,
//                    item: NutritionGuidanceItem(
//                        title: "Recover after \(profile.title.lowercased())",
//                        message: "You completed a demanding activity. Add protein, water and a simple recovery meal.",
//                        triggerLabel: "Completed at \(timeString(completed.date))",
//                        icon: "leaf.fill",
//                        color: green,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.recovery, .highProtein, .antiInflammatory]),
//                        suggestedTypes: [.recovery, .highProtein, .antiInflammatory]
//                    )
//                )
//            )
//        }
//
//        return result
//    }
//
//    private func buildHydrationGuidance(
//        context: DayNutritionContext,
//        meals: [Meals]
//    ) -> [GuidanceCandidate] {
//        guard context.needsHydrationFocus else { return [] }
//
//        let priority = context.hasSauna ? 92 : 72
//
//        return [
//            GuidanceCandidate(
//                priority: priority,
//                item: NutritionGuidanceItem(
//                    title: context.hasSauna ? "Hydration comes first" : "Focus on hydration",
//                    message: context.hasSauna
//                    ? "Sauna is planned today. Drink earlier and add electrolytes if you sweat more."
//                    : "Today’s activity may increase water needs. Drink steadily and add water-rich foods.",
//                    triggerLabel: "Based on today’s plan",
//                    icon: "drop.fill",
//                    color: blue,
//                    suggestedMeal: pickMeal(from: meals, preferredTypes: [.hydration, .balanced, .recovery]),
//                    suggestedTypes: [.hydration, .balanced, .recovery]
//                )
//            )
//        ]
//    }
//
//    private func buildMealBalanceGuidance(
//        context: DayNutritionContext,
//        meals: [Meals]
//    ) -> [GuidanceCandidate] {
//        guard context.hasPlannedMeals else { return [] }
//
//        if context.hasWorkout {
//            return [
//                GuidanceCandidate(
//                    priority: 50,
//                    item: NutritionGuidanceItem(
//                        title: "Balance around activity",
//                        message: "Eat carbs before activity and protein after. Keep drinking water through the day.",
//                        triggerLabel: "Meals + activity today",
//                        icon: "fork.knife",
//                        color: green,
//                        suggestedMeal: pickMeal(from: meals, preferredTypes: [.balanced, .highProtein, .preWorkout]),
//                        suggestedTypes: [.balanced, .highProtein, .preWorkout]
//                    )
//                )
//            ]
//        }
//
//        return []
//    }
//
//    private func buildDayContext(from activities: [PlannedActivity]) -> DayNutritionContext {
//        let now = Date()
//
//        let upcoming = activities
//            .filter { $0.date >= now }
//            .sorted { $0.date < $1.date }
//
//        let completed = activities
//            .filter { $0.date < now }
//            .sorted { $0.date > $1.date }
//
//        let profiles = activities.map { classifier.profile(for: $0) }
//        let categories = profiles.map { category(for: $0) }
//
//        let lastDemandingCompletedActivity = completed.first { activity in
//            let profile = classifier.profile(for: activity)
//            return profile.effort == .high || profile.recoveryNeed == .high
//        }
//
//        return DayNutritionContext(
//            activities: activities,
//            nextActivity: upcoming.first,
//            completedActivities: completed,
//            hasSauna: categories.contains(.sauna),
//            hasWalk: categories.contains(.walk),
//            hasWorkout: categories.contains(.workout),
//            hasRecovery: categories.contains(.recovery),
//            hasPlannedMeals: categories.contains(.meal),
//            hasHighHydrationNeed: profiles.contains { $0.hydrationNeed == .high },
//            hasHighRecoveryNeed: profiles.contains { $0.recoveryNeed == .high },
//            lowReadiness: healthManager.readyScore < 6,
//            poorSleep: healthManager.sleepHours < 6.5,
//            lastDemandingCompletedActivity: lastDemandingCompletedActivity
//        )
//    }
//
//    private struct DayNutritionContext {
//        let activities: [PlannedActivity]
//        let nextActivity: PlannedActivity?
//        let completedActivities: [PlannedActivity]
//
//        let hasSauna: Bool
//        let hasWalk: Bool
//        let hasWorkout: Bool
//        let hasRecovery: Bool
//        let hasPlannedMeals: Bool
//
//        let hasHighHydrationNeed: Bool
//        let hasHighRecoveryNeed: Bool
//
//        let lowReadiness: Bool
//        let poorSleep: Bool
//
//        let lastDemandingCompletedActivity: PlannedActivity?
//
//        var lowBodyState: Bool {
//            lowReadiness || poorSleep
//        }
//
//        var needsHydrationFocus: Bool {
//            hasSauna || hasHighHydrationNeed || lowBodyState
//        }
//    }
//
//    private struct GuidanceCandidate {
//        let priority: Int
//        let item: NutritionGuidanceItem
//    }
//
//    private enum ActivityCategory: Equatable {
//        case sauna
//        case walk
//        case workout
//        case recovery
//        case meal
//        case other
//    }
//
//    private func category(for profile: ActivityNutritionProfile) -> ActivityCategory {
//        let title = profile.title.lowercased()
//
//        if title.contains("sauna") {
//            return .sauna
//        }
//
//        if title.contains("walk") {
//            return .walk
//        }
//
//        if title.contains("meal")
//            || title.contains("breakfast")
//            || title.contains("lunch")
//            || title.contains("dinner")
//            || title.contains("snack") {
//            return .meal
//        }
//
//        if profile.effort == .high || profile.proteinNeed == .high || profile.carbsNeed == .high {
//            return .workout
//        }
//
//        if profile.recoveryNeed == .high {
//            return .recovery
//        }
//
//        return .other
//    }
//
//    private func balancedDefaultGuidance(meals: [Meals]) -> NutritionGuidanceItem {
//        NutritionGuidanceItem(
//            title: "Balanced day ahead",
//            message: "No intense activity planned today. Keep meals balanced and drink water regularly.",
//            triggerLabel: "No intense activity today",
//            icon: "sparkles",
//            color: green,
//            suggestedMeal: pickMeal(from: meals, preferredTypes: [.balanced, .hydration, .recovery]),
//            suggestedTypes: [.balanced, .hydration, .recovery]
//        )
//    }
//
//    private func fetchTodayActivities() -> [PlannedActivity] {
//        let calendar = Calendar.current
//        let startOfDay = calendar.startOfDay(for: Date())
//
//        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
//            return []
//        }
//
//        let descriptor = FetchDescriptor<PlannedActivity>(
//            predicate: #Predicate { activity in
//                activity.date >= startOfDay && activity.date < endOfDay
//            },
//            sortBy: [
//                SortDescriptor(\.date, order: .forward)
//            ]
//        )
//
//        return (try? modelContext.fetch(descriptor)) ?? []
//    }
//
//    private func pickMeal(
//        from meals: [Meals],
//        preferredTypes: [MealsType]
//    ) -> Meals? {
//        for type in preferredTypes {
//            if let meal = meals.first(where: { $0.type == type }) {
//                return meal
//            }
//        }
//
//        return meals.first
//    }
//
//    private func timeString(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "h:mm a"
//        return formatter.string(from: date)
//    }
//
//    private var green: Color {
//        Color(red: 0.10, green: 0.65, blue: 0.35)
//    }
//
//    private var blue: Color {
//        Color(red: 0.10, green: 0.48, blue: 0.90)
//    }
//
//    private var orange: Color {
//        Color(red: 1.00, green: 0.48, blue: 0.12)
//    }
//
//    private var purple: Color {
//        Color(red: 0.48, green: 0.28, blue: 0.82)
//    }
//    
//    func generateCoachCard() -> CoachCardGuidance {
//        let activities = fetchTodayActivities()
//        let context = buildDayContext(from: activities)
//
//        let waterGoal: Double = 1.5
//        let waterProgress = waterGoal > 0 ? min(max(healthManager.waterLiters / waterGoal, 0), 1) : 0
//
//        if waterProgress < 0.45 {
//            return CoachCardGuidance(
//                state: .hydration,
//                title: "Hydration focus now",
//                mainAction: "Drink 500 ml water now",
//                message: "Hydration is behind today’s needs. Start with water before heavier meals.",
//                icon: "drop.fill",
//                color: blue,
//                pills: [
//                    CoachPillItem(
//                        icon: "drop.fill",
//                        title: "Hydrate",
//                        subtitle: "500 ml water",
//                        color: blue
//                    ),
//                    CoachPillItem(
//                        icon: "fork.knife",
//                        title: "Recovery fuel",
//                        subtitle: "Protein + carbs",
//                        color: green
//                    )
//                ]
//            )
//        }
//
//        if let completed = context.lastDemandingCompletedActivity {
//            let profile = classifier.profile(for: completed)
//
//            return CoachCardGuidance(
//                state: .recovery,
//                title: "Recovery focus now",
//                mainAction: "Refuel with protein and fluids",
//                message: "\(timeString(completed.date)) \(profile.title) completed. Your body needs simple recovery fuel.",
//                icon: "leaf.fill",
//                color: green,
//                pills: [
//                    CoachPillItem(
//                        icon: "fork.knife",
//                        title: "Recovery meal",
//                        subtitle: "Protein + carbs",
//                        color: green
//                    ),
//                    CoachPillItem(
//                        icon: "drop.fill",
//                        title: "Hydrate",
//                        subtitle: "Keep sipping",
//                        color: blue
//                    )
//                ]
//            )
//        }
//
//        if let next = context.nextActivity {
//            let profile = classifier.profile(for: next)
//            let category = category(for: profile)
//
//            if category == .workout || category == .walk || category == .sauna {
//                return CoachCardGuidance(
//                    state: .activity,
//                    title: category == .sauna ? "Prepare for sauna" : "Prepare for activity",
//                    mainAction: category == .sauna ? "Hydrate before sauna" : "Add easy energy before activity",
//                    message: "\(profile.title) at \(timeString(next.date)). Keep energy stable and avoid heavy food right before it.",
//                    icon: category == .sauna ? "drop.fill" : "bolt.fill",
//                    color: category == .sauna ? blue : orange,
//                    pills: [
//                        CoachPillItem(
//                            icon: category == .sauna ? "drop.fill" : "bolt.fill",
//                            title: category == .sauna ? "Hydrate" : "Fuel up",
//                            subtitle: category == .sauna ? "Before sauna" : "Easy carbs",
//                            color: category == .sauna ? blue : orange
//                        ),
//                        CoachPillItem(
//                            icon: "fork.knife",
//                            title: "Keep light",
//                            subtitle: "Avoid heavy meal",
//                            color: green
//                        )
//                    ]
//                )
//            }
//        }
//
//        if context.lowBodyState {
//            return CoachCardGuidance(
//                state: .sleep,
//                title: "Recovery support today",
//                mainAction: "Keep meals light and hydrate",
//                message: "Sleep or readiness looks lower today. Choose easier meals and protect recovery.",
//                icon: "moon.fill",
//                color: purple,
//                pills: [
//                    CoachPillItem(
//                        icon: "moon.fill",
//                        title: "Light meal",
//                        subtitle: "Low stress",
//                        color: purple
//                    ),
//                    CoachPillItem(
//                        icon: "drop.fill",
//                        title: "Hydrate",
//                        subtitle: "Support recovery",
//                        color: blue
//                    )
//                ]
//            )
//        }
//
//        return CoachCardGuidance(
//            state: .balanced,
//            title: "Balanced support now",
//            mainAction: "Stay steady with water and balanced food",
//            message: "Your day looks balanced. Keep drinking water and follow your planned meals.",
//            icon: "sparkles",
//            color: green,
//            pills: [
//                CoachPillItem(
//                    icon: "sparkles",
//                    title: "Stay balanced",
//                    subtitle: "Keep routine",
//                    color: green
//                ),
//                CoachPillItem(
//                    icon: "drop.fill",
//                    title: "Hydrate",
//                    subtitle: "Keep sipping",
//                    color: blue
//                )
//            ]
//        )
//    }
//}
//
////struct FastFuelItem: Identifiable {
////    let id = UUID()
////    let imageName: String
////    let title: String
////    let amount: String
////    let reason: String
////}
//
//struct CoachCardGuidance {
//    let state: CoachState
//    let title: String
//    let mainAction: String
//    let message: String
//    let icon: String
//    let color: Color
//    let pills: [CoachPillItem]
//}
//
//struct CoachPillItem: Identifiable {
//    let id = UUID()
//    let icon: String
//    let title: String
//    let subtitle: String
//    let color: Color
//}
//
//enum CoachState {
//    case hydration
//    case recovery
//    case activity
//    case sleep
//    case balanced
//}
