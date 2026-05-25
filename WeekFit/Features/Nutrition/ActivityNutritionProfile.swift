//import SwiftUI
//
//struct ActivityNutritionProfile {
//    let title: String
//    let icon: String
//    let color: Color
//
//    let effort: ActivityEffort
//    let hydrationNeed: NutritionNeed
//    let proteinNeed: NutritionNeed
//    let carbsNeed: NutritionNeed
//    let recoveryNeed: NutritionNeed
//
//    let beforeMessage: String
//    let afterMessage: String
//
//    let beforeMealTypes: [MealsType]
//    let afterMealTypes: [MealsType]
//}
//
//enum ActivityEffort {
//    case low
//    case medium
//    case high
//}
//
//enum NutritionNeed {
//    case low
//    case medium
//    case high
//}
//
//extension ActivityNutritionProfile {
//
//    static let strength = ActivityNutritionProfile(
//        title: "Strength workout",
//        icon: "dumbbell.fill",
//        color: Color(red: 0.95, green: 0.45, blue: 0.10),
//        effort: .high,
//        hydrationNeed: .medium,
//        proteinNeed: .high,
//        carbsNeed: .high,
//        recoveryNeed: .high,
//        beforeMessage: "Have protein and slow carbs 1–2h before training to support energy and performance.",
//        afterMessage: "Prioritize protein and recovery-focused foods after training to support muscle repair.",
//        beforeMealTypes: [.preWorkout, .highProtein, .balanced],
//        afterMealTypes: [.recovery, .highProtein, .antiInflammatory]
//    )
//
//    static let running = ActivityNutritionProfile(
//        title: "Run",
//        icon: "figure.run",
//        color: Color(red: 0.95, green: 0.55, blue: 0.15),
//        effort: .high,
//        hydrationNeed: .high,
//        proteinNeed: .medium,
//        carbsNeed: .high,
//        recoveryNeed: .high,
//        beforeMessage: "Choose easy carbs and fluids before your run to support energy without heavy digestion.",
//        afterMessage: "Rehydrate and add protein with carbs after running to support recovery.",
//        beforeMealTypes: [.preWorkout, .hydration, .balanced],
//        afterMealTypes: [.recovery, .hydration, .highProtein]
//    )
//
//    static let cardio = ActivityNutritionProfile(
//        title: "Cardio session",
//        icon: "heart.fill",
//        color: Color(red: 0.95, green: 0.35, blue: 0.35),
//        effort: .high,
//        hydrationNeed: .high,
//        proteinNeed: .medium,
//        carbsNeed: .high,
//        recoveryNeed: .high,
//        beforeMessage: "Add carbs and fluids before cardio to support steady energy.",
//        afterMessage: "Focus on hydration, protein and balanced carbs after cardio.",
//        beforeMealTypes: [.preWorkout, .hydration, .balanced],
//        afterMealTypes: [.recovery, .hydration, .highProtein]
//    )
//
//    static let sauna = ActivityNutritionProfile(
//        title: "Sauna",
//        icon: "drop.fill",
//        color: Color(red: 0.10, green: 0.48, blue: 0.90),
//        effort: .medium,
//        hydrationNeed: .high,
//        proteinNeed: .low,
//        carbsNeed: .low,
//        recoveryNeed: .medium,
//        beforeMessage: "Focus on fluids and mineral-rich foods before sauna to support hydration.",
//        afterMessage: "Rehydrate after sauna and choose light recovery-friendly foods.",
//        beforeMealTypes: [.hydration, .balanced],
//        afterMealTypes: [.hydration, .recovery]
//    )
//
//    static let walking = ActivityNutritionProfile(
//        title: "Walk",
//        icon: "figure.walk",
//        color: Color(red: 0.35, green: 0.65, blue: 0.45),
//        effort: .low,
//        hydrationNeed: .medium,
//        proteinNeed: .low,
//        carbsNeed: .medium,
//        recoveryNeed: .low,
//        beforeMessage: "A light balanced meal and regular hydration are enough for today’s walk.",
//        afterMessage: "Keep hydration steady and continue with balanced meals.",
//        beforeMealTypes: [.balanced, .hydration],
//        afterMealTypes: [.balanced, .hydration]
//    )
//
//    static let mobility = ActivityNutritionProfile(
//        title: "Mobility",
//        icon: "figure.cooldown",
//        color: Color(red: 0.45, green: 0.60, blue: 0.85),
//        effort: .low,
//        hydrationNeed: .medium,
//        proteinNeed: .low,
//        carbsNeed: .low,
//        recoveryNeed: .medium,
//        beforeMessage: "Keep food light and hydration steady before mobility work.",
//        afterMessage: "Support recovery with balanced, anti-inflammatory foods.",
//        beforeMealTypes: [.balanced, .hydration],
//        afterMealTypes: [.recovery, .antiInflammatory, .balanced]
//    )
//
//    static let recovery = ActivityNutritionProfile(
//        title: "Recovery",
//        icon: "leaf.fill",
//        color: Color(red: 0.10, green: 0.65, blue: 0.35),
//        effort: .low,
//        hydrationNeed: .medium,
//        proteinNeed: .medium,
//        carbsNeed: .low,
//        recoveryNeed: .high,
//        beforeMessage: "Choose light, recovery-focused nutrition and keep hydration steady.",
//        afterMessage: "Prioritize protein, colorful foods and healthy fats to support recovery.",
//        beforeMealTypes: [.recovery, .hydration, .balanced],
//        afterMealTypes: [.recovery, .antiInflammatory, .sleepSupport]
//    )
//
//    static let balanced = ActivityNutritionProfile(
//        title: "Balanced day",
//        icon: "sparkles",
//        color: WeekFitTheme.meal,
//        effort: .low,
//        hydrationNeed: .medium,
//        proteinNeed: .medium,
//        carbsNeed: .medium,
//        recoveryNeed: .low,
//        beforeMessage: "Your day looks light. Focus on balanced meals, steady hydration and stable energy.",
//        afterMessage: "Keep meals balanced and avoid long gaps without food.",
//        beforeMealTypes: [.balanced, .hydration],
//        afterMealTypes: [.balanced, .antiInflammatory]
//    )
//}
