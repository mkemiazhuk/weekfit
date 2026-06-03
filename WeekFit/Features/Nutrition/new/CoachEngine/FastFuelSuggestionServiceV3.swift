//import SwiftUI
//import SwiftData
//
//final class FastFuelSuggestionServiceV3 {
//
//    private let calendar = Calendar.current
//
//    func generate(
//        guidance: CoachGuidanceV3?,
//        currentWater: Double,
//        waterGoal: Double,
//        currentProtein: Double,
//        proteinGoal: Double,
//        currentCarbs: Double,
//        carbsGoal: Double,
//        plannedActivities: [PlannedActivity],
//        selectedDate: Date,
//        brain: HumanBrain.State?
//    ) -> [FastFuelItem] {
//
//        guard let guidance, guidance.shouldSurface else {
//            return []
//        }
//
//        let pool = masterPool()
//        let load = activityLoad(from: guidance.phase)
//
//        let candidates = guidance.supportActions
//            .flatMap { items(for: $0.type, from: pool, guidance: guidance) }
//
//        let uniqueCandidates = unique(candidates)
//            .filter { isAllowedByScenario(item: $0, guidance: guidance) }
//        
//        let isMorning =
//            Calendar.current.component(.hour, from: Date()) < 12
//
//        let noFoodLogged =
//            brain?.hasAnyFoodLogged == false
//        
//        let hasFoodLogged =
//            brain?.hasAnyFoodLogged == true
//
//        if guidance.opportunity.type == .prepareForHeat {
//            return prioritized(
//                uniqueCandidates,
//                titles: hasFoodLogged
//                    ? [
//                        "Water",
//                        "Mineral Water"
//                    ]
//                    : [
//                        "Water",
//                        "Banana",
//                        "Mineral Water"
//                       
//                    ]
//            )
//        }
//        
//        if guidance.opportunity.type == .recoverAfterWorkout,
//           load == .low,
//           isMorning,
//           noFoodLogged {
//
//            return prioritized(
//                uniqueCandidates,
//                titles: [
//                    "Water",
//                    "Oats",
//                    "Greek Yogurt"
//                ]
//            )
//        }
//
//        if guidance.opportunity.type == .recoverAfterWorkout {
//            switch load {
//            case .extreme:
//                return prioritized(
//                    uniqueCandidates,
//                    titles: [
//                        "Rice + Chicken Bowl",
//                        "Recovery Shake",
//                        "Oats + Yogurt + Berries",
//                        "Isotonic Drink",
//                        "Mineral Water"
//                    ]
//                )
//
//            case .high:
//                return prioritized(
//                    uniqueCandidates,
//                    titles: [
//                        "Oats + Yogurt + Berries",
//                        "Rice + Chicken Bowl",
//                        "Recovery Shake",
//                        "Isotonic Drink",
//                        "Mineral Water"
//                    ]
//                )
//
//            case .moderate, .low:
//                break
//            }
//        }
//
//        let selected = diversified(
//            uniqueCandidates,
//            guidance: guidance
//        )
//
//        return Array(selected.prefix(3))
//    }
//    func coachMessages(
//        from items: [FastFuelItem]
//    ) -> [String] {
//
//        var result: [String] = []
//        var seen = Set<String>()
//
//        for item in items {
//            let message = item.reason.trimmingCharacters(in: .whitespacesAndNewlines)
//
//            guard !message.isEmpty,
//                  !seen.contains(message) else {
//                continue
//            }
//
//            result.append(message)
//            seen.insert(message)
//        }
//
//        return Array(result.prefix(3))
//    }
//
//}
//
//// MARK: - Item Selection
//
//private extension FastFuelSuggestionServiceV3 {
//
//    func items(
//        for action: CoachSupportActionTypeV3,
//        from pool: [FastFuelItem],
//        guidance: CoachGuidanceV3
//    ) -> [FastFuelItem] {
//
//        let load = activityLoad(from: guidance.phase)
//
//        switch action {
//
//        case .lightFueling:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Banana" ||
//                               $0.title == "Water" ||
//                               $0.title == "Herbal Tea"
//                    }
//
//                    return $0.title == "Banana" ||
//                           $0.title == "Rice Cakes" ||
//                           $0.title == "Isotonic Drink" ||
//                           $0.title == "Oats"
//                },
//                guidance: guidance
//            )
//
//        case .hydrateBeforeSession:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Water" ||
//                               $0.title == "Herbal Tea"
//                    }
//
//                    return $0.title == "Water" ||
//                           $0.title == "Mineral Water" ||
//                           $0.title == "Isotonic Drink"
//                },
//                guidance: guidance
//            )
//
//        case .breathingReset:
//            return contextualized(
//                pool.filter {
//                    $0.title == "Herbal Tea" ||
//                    $0.title == "Water"
//                },
//                guidance: guidance
//            )
//
//        case .mobilityPrep:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Water" ||
//                               $0.title == "Herbal Tea"
//                    }
//
//                    return $0.title == "Water" ||
//                           $0.title == "Banana" ||
//                           $0.title == "Mineral Water"
//                },
//                guidance: guidance
//            )
//
//        case .keepDigestionLight:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Water" ||
//                               $0.title == "Herbal Tea" ||
//                               $0.title == "Banana"
//                    }
//
//                    return $0.title == "Banana" ||
//                           $0.title == "Rice Cakes" ||
//                           $0.title == "Water"
//                },
//                guidance: guidance
//            )
//
//        case .steadyHydration:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Water" ||
//                               $0.title == "Herbal Tea"
//                    }
//
//                    return $0.title == "Water" ||
//                           $0.title == "Mineral Water" ||
//                           $0.title == "Isotonic Drink"
//                },
//                guidance: guidance
//            )
//
//        case .sustainEnergy:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Banana" ||
//                               $0.title == "Water"
//                    }
//
//                    return $0.title == "Isotonic Drink" ||
//                           $0.title == "Banana" ||
//                           $0.title == "Rice Cakes"
//                },
//                guidance: guidance
//            )
//
//        case .controlIntensity:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Water" ||
//                               $0.title == "Herbal Tea"
//                    }
//
//                    return $0.title == "Water" ||
//                           $0.title == "Mineral Water" ||
//                           $0.title == "Herbal Tea"
//                },
//                guidance: guidance
//            )
//
//        case .cooldown:
//            return []
//
//        case .rehydrateGradually:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Water" ||
//                               $0.title == "Herbal Tea"
//                    }
//
//                    return $0.title == "Water" ||
//                           $0.title == "Mineral Water" ||
//                           $0.title == "Isotonic Drink" ||
//                           $0.title == "Kefir 1%"
//                },
//                guidance: guidance
//            )
//
//        case .lightRecoveryMovement:
//            return contextualized(
//                pool.filter {
//                    if load == .low {
//                        return $0.title == "Water" ||
//                               $0.title == "Herbal Tea"
//                    }
//
//                    return $0.title == "Kefir 1%" ||
//                           $0.title == "Greek Yogurt" ||
//                           $0.title == "Water"
//                },
//                guidance: guidance
//            )
//
//        case .downshiftNervousSystem:
//            return contextualized(
//                pool.filter {
//                    $0.title == "Herbal Tea" ||
//                    $0.title == "Kefir 1%" ||
//                    $0.title == "Water"
//                },
//                guidance: guidance
//            )
//
//        case .startRecoveryNutrition:
//            return contextualized(
//                pool.filter {
//                    $0.title == "Greek Yogurt" ||
//                    $0.title == "Kefir 1%" ||
//                    $0.title == "Protein Bar" ||
//                    $0.title == "Oats"
//                },
//                guidance: guidance
//            )
//
//        case .recoveryMeal:
//            if load == .extreme {
//                return contextualized(
//                    pool.filter {
//                        $0.title == "Rice + Chicken Bowl" ||
//                        $0.title == "Recovery Shake" ||
//                        $0.title == "Oats + Yogurt + Berries"
//                    },
//                    guidance: guidance
//                )
//            }
//
//            if load == .high {
//                return contextualized(
//                    pool.filter {
//                        $0.title == "Oats + Yogurt + Berries" ||
//                        $0.title == "Rice + Chicken Bowl" ||
//                        $0.title == "Recovery Shake"
//                    },
//                    guidance: guidance
//                )
//            }
//
//            return contextualized(
//                pool.filter {
//                    $0.title == "Greek Yogurt" ||
//                    $0.title == "Kefir 1%" ||
//                    $0.title == "Oats"
//                },
//                guidance: guidance
//            )
//
//        case .electrolyteRecovery:
//            return contextualized(
//                pool.filter {
//                    $0.title == "Mineral Water" ||
//                    $0.title == "Isotonic Drink" ||
//                    $0.title == "Water"
//                },
//                guidance: guidance
//            )
//
//        case .sleepPriority:
//            return contextualized(
//                pool.filter {
//                    $0.title == "Herbal Tea" ||
//                    $0.title == "Kefir 1%" ||
//                    $0.title == "Water"
//                },
//                guidance: guidance
//            )
//
//        case .stayConsistent:
//            return contextualized(
//                pool.filter {
//                    $0.title == "Water" ||
//                    $0.title == "Herbal Tea" ||
//                    $0.title == "Kefir 1%"
//                },
//                guidance: guidance
//            )
//        }
//    }
//
//    func activityLoad(from phase: CoachActivityPhaseV3) -> CoachActivityLoadV3 {
//        switch phase {
//        case .preparing(let activity, _, _),
//             .active(let activity, _),
//             .recovering(let activity, _, _):
//            return CoachActivityContextResolverV3.load(for: activity)
//
//        case .stable:
//            return .low
//        }
//    }
//
//    func prioritized(
//        _ items: [FastFuelItem],
//        titles: [String]
//    ) -> [FastFuelItem] {
//
//        var selected: [FastFuelItem] = []
//        var usedTitles = Set<String>()
//
//        for title in titles {
//            guard selected.count < 3 else { break }
//
//            if let item = items.first(where: { $0.title == title && !usedTitles.contains($0.title) }) {
//                selected.append(item)
//                usedTitles.insert(item.title)
//            }
//        }
//
//        for item in items where selected.count < 3 {
//            guard !usedTitles.contains(item.title) else { continue }
//            selected.append(item)
//            usedTitles.insert(item.title)
//        }
//
//        return selected
//    }
//
//    func diversified(
//        _ items: [FastFuelItem],
//        guidance: CoachGuidanceV3
//    ) -> [FastFuelItem] {
//
//        let categoryOrder: [FuelSuggestionCategory]
//
//        switch guidance.opportunity.type {
//        case .prepareForEndurance:
//            categoryOrder = [.hydration, .carbs, .electrolytes, .light, .calm]
//
//        case .prepareForWorkout:
//            categoryOrder = [.hydration, .carbs, .light, .electrolytes, .calm]
//
//        case .prepareForHeat:
//            categoryOrder = [.hydration, .electrolytes, .calm, .light]
//
//        case .activeEnduranceSupport:
//            categoryOrder = [.hydration, .carbs, .electrolytes, .light]
//
//        case .activeWorkoutSupport:
//            categoryOrder = [.hydration, .electrolytes, .carbs, .light]
//
//        case .activeHeatSupport:
//            categoryOrder = [.electrolytes, .hydration, .calm, .light]
//
//        case .recoverAfterWorkout:
//            let load = activityLoad(from: guidance.phase)
//
//            switch load {
//            case .extreme:
//                categoryOrder = [.carbs, .protein, .electrolytes, .hydration, .calm]
//
//            case .high:
//                categoryOrder = [.protein, .carbs, .hydration, .electrolytes, .calm]
//
//            case .moderate:
//                categoryOrder = [.protein, .hydration, .carbs, .calm]
//
//            case .low:
//                categoryOrder = [.hydration, .calm, .light]
//            }
//
//        case .recoverAfterHeat:
//            categoryOrder = [.electrolytes, .hydration, .protein, .calm]
//
//        case .protectRecoveryBeforeActivity:
//            categoryOrder = [.hydration, .carbs, .electrolytes, .light, .calm]
//
//        case .stable:
//            categoryOrder = [.hydration, .calm, .protein, .light]
//        }
//
//        var selected: [FastFuelItem] = []
//        var usedTitles = Set<String>()
//
//        func pickFirst(from category: FuelSuggestionCategory) {
//            guard selected.count < 3 else { return }
//
//            if let item = items.first(where: {
//                !usedTitles.contains($0.title) &&
//                category.matches($0)
//            }) {
//                selected.append(item)
//                usedTitles.insert(item.title)
//            }
//        }
//
//        categoryOrder.forEach { pickFirst(from: $0) }
//
//        for item in items where selected.count < 3 {
//            guard !usedTitles.contains(item.title) else { continue }
//            selected.append(item)
//            usedTitles.insert(item.title)
//        }
//
//        return selected
//    }
//
//    func contextualized(
//        _ items: [FastFuelItem],
//        guidance: CoachGuidanceV3
//    ) -> [FastFuelItem] {
//
//        let activityName = activityName(from: guidance.phase)
//
//        return items.map { item in
//            let reason = contextualReason(
//                for: item,
//                guidance: guidance,
//                activityName: activityName
//            )
//
//            return FastFuelItem(
//                imageName: item.imageName,
//                title: item.title,
//                amount: item.amount,
//                reason: reason,
//                tags: item.tags,
//                caloriesPer100g: item.caloriesPer100g,
//                proteinPer100g: item.proteinPer100g,
//                carbsPer100g: item.carbsPer100g,
//                fatsPer100g: item.fatsPer100g,
//                standardWeightGrams: item.standardWeightGrams
//            )
//        }
//    }
//
//
//    func sportText(from guidance: CoachGuidanceV3) -> String {
//        switch guidance.phase {
//        case .preparing(let activity, _, _),
//             .active(let activity, _),
//             .recovering(let activity, _, _):
//            let text = "\(activity.title) \(activity.type)".lowercased()
//
//            if text.contains("cycling") ||
//               text.contains("cycle") ||
//               text.contains("bike") ||
//               text.contains("ride") {
//                return "ride"
//            }
//
//            if text.contains("run") ||
//               text.contains("running") {
//                return "run"
//            }
//
//            if text.contains("tennis") {
//                return "court session"
//            }
//
//            if text.contains("squash") {
//                return "court session"
//            }
//
//            if text.contains("sauna") ||
//               text.contains("heat") {
//                return "heat session"
//            }
//
//            if text.contains("upper body") ||
//               text.contains("strength") ||
//               text.contains("gym") ||
//               text.contains("workout") ||
//               text.contains("training") {
//                return "training"
//            }
//
//            return "session"
//
//        case .stable:
//            return "session"
//        }
//    }
//
//    func isLongSession(_ guidance: CoachGuidanceV3) -> Bool {
//        switch guidance.phase {
//        case .preparing(let activity, _, _),
//             .active(let activity, _),
//             .recovering(let activity, _, _):
//            return activity.durationMinutes >= 60
//
//        case .stable:
//            return false
//        }
//    }
//
//    func contextualReason(
//        for item: FastFuelItem,
//        guidance: CoachGuidanceV3,
//        activityName: String
//    ) -> String {
//
//        let sport = sportText(from: guidance)
//        let longSession = isLongSession(guidance)
//
//        switch guidance.opportunity.type {
//
//        case .prepareForEndurance:
//            switch item.title {
//            case "Water":
//                return "Drink 300–500 ml before the \(sport)"
//            case "Mineral Water":
//                return longSession
//                    ? "Take electrolytes if you expect to sweat"
//                    : "Use minerals only if hydration feels low"
//            case "Isotonic Drink":
//                return longSession
//                    ? "Use isotonic drink for carbs + electrolytes"
//                    : "Use isotonic only if energy is low"
//            case "Banana":
//                return longSession
//                    ? "Bring a banana for 45–60 min into the session"
//                    : "Eat a banana if you feel underfueled"
//            case "Rice Cakes":
//                return longSession
//                    ? "Bring light carbs for the second half"
//                    : "Use light carbs only if energy is low"
//            case "Oats":
//                return "Eat oats only if you have enough time to digest"
//            default:
//                return item.reason
//            }
//
//        case .prepareForWorkout:
//            let load = activityLoad(from: guidance.phase)
//
//            switch item.title {
//            case "Water":
//                return "Drink 300–500 ml before training"
//            case "Mineral Water":
//                return load == .low
//                    ? "Minerals are optional for this session"
//                    : "Add minerals if you expect heavy sweating"
//            case "Isotonic Drink":
//                return load == .low
//                    ? "Skip isotonic unless energy is low"
//                    : "Use isotonic only for longer or sweaty training"
//            case "Banana":
//                return load == .low
//                    ? "Small carbs only if energy feels low"
//                    : "Eat easy carbs before training"
//            case "Rice Cakes":
//                return "Keep carbs light before movement"
//            case "Oats":
//                return "Use steady carbs only if you have time"
//            case "Herbal Tea":
//                return "Use calm hydration if this is light work"
//            default:
//                return item.reason
//            }
//
//        case .prepareForHeat:
//            switch item.title {
//            case "Water":
//                return "Hydrate before heat exposure"
//            case "Mineral Water":
//                return "Add minerals before heat"
//            case "Isotonic Drink":
//                return "Use electrolytes if heat will be long"
//            case "Banana", "Rice Cakes":
//                return "Keep food light before heat"
//            default:
//                return item.reason
//            }
//
//        case .activeEnduranceSupport:
//            switch item.title {
//            case "Water":
//                return "Sip water regularly during the \(sport)"
//            case "Mineral Water":
//                return "Use electrolytes if sweating heavily"
//            case "Isotonic Drink":
//                return longSession
//                    ? "Use carbs + electrolytes during long effort"
//                    : "Use isotonic only if energy drops"
//            case "Banana":
//                return longSession
//                    ? "Eat easy carbs every 45–60 min"
//                    : "Use banana only if energy drops"
//            case "Rice Cakes":
//                return longSession
//                    ? "Use light carbs during longer effort"
//                    : "Keep fuel simple unless energy drops"
//            default:
//                return item.reason
//            }
//
//        case .activeWorkoutSupport:
//            switch item.title {
//            case "Water":
//                return "Sip water during training"
//            case "Mineral Water":
//                return "Use minerals only if sweating heavily"
//            case "Isotonic Drink":
//                return "Use isotonic only for long or intense work"
//            case "Banana", "Rice Cakes":
//                return "Add easy carbs only if energy dips"
//            default:
//                return item.reason
//            }
//
//        case .activeHeatSupport:
//            switch item.title {
//            case "Water":
//                return "Sip water calmly around heat"
//            case "Mineral Water":
//                return "Use minerals to support hydration"
//            case "Isotonic Drink":
//                return "Use electrolytes if heat feels draining"
//            case "Herbal Tea":
//                return "Use calm hydration after heat"
//            default:
//                return item.reason
//            }
//
//        case .recoverAfterWorkout:
//            let load = activityLoad(from: guidance.phase)
//
//            switch item.title {
//            case "Water":
//                return load == .low
//                    ? "Drink water and return to normal routine"
//                    : "Rehydrate gradually over the next hour"
//            case "Mineral Water":
//                return "Replace minerals after sweating"
//            case "Isotonic Drink":
//                return load == .extreme
//                    ? "Use fluids + carbs after heavy work"
//                    : "Use electrolytes if you sweated a lot"
//            case "Kefir 1%":
//                return "Use light protein + fluids"
//            case "Greek Yogurt":
//                return "Add protein to support recovery"
//            case "Protein Bar":
//                return "Use convenient protein if no meal is near"
//            case "Oats":
//                return "Restore steady energy after the session"
//            case "Herbal Tea":
//                return "Use calm hydration before sleep"
//            case "Rice + Chicken Bowl":
//                return "Eat a real recovery meal"
//            case "Oats + Yogurt + Berries":
//                return "Recover with carbs + protein"
//            case "Recovery Shake":
//                return "Use fast protein + carbs after training"
//            default:
//                return item.reason
//            }
//
//        case .recoverAfterHeat:
//            switch item.title {
//            case "Water":
//                return "Rehydrate calmly after heat"
//            case "Mineral Water":
//                return "Replace minerals after heat"
//            case "Isotonic Drink":
//                return "Use electrolytes after heat exposure"
//            case "Kefir 1%":
//                return "Use light recovery if appetite is low"
//            case "Herbal Tea":
//                return "Use gentle hydration after heat"
//            default:
//                return item.reason
//            }
//
//        case .protectRecoveryBeforeActivity:
//            switch item.title {
//            case "Water":
//                return "Hydrate before the next block"
//            case "Mineral Water":
//                return "Use minerals if this adds more sweat"
//            case "Isotonic Drink":
//                return "Use isotonic only for long or sweaty work"
//            case "Banana":
//                return "Bring easy carbs if the session runs long"
//            case "Rice Cakes":
//                return "Keep carbs light and easy to digest"
//            case "Kefir 1%":
//                return "Keep recovery support light"
//            case "Greek Yogurt", "Protein Bar":
//                return "Save protein for after the session"
//            case "Herbal Tea":
//                return "Stay calm before the next block"
//            default:
//                return item.reason
//            }
//
//        case .stable:
//            return item.reason
//        }
//    }
//
//    func activityName(from phase: CoachActivityPhaseV3) -> String {
//        switch phase {
//        case .preparing(let activity, _, _),
//             .active(let activity, _),
//             .recovering(let activity, _, _):
//
//            let cleanTitle = activity.title
//                .trimmingCharacters(in: .whitespacesAndNewlines)
//                .lowercased()
//
//            return cleanTitle.isEmpty ? "this activity" : cleanTitle
//
//        case .stable:
//            return "this activity"
//        }
//    }
//}
//
//// MARK: - Diversity Category
//
//private enum FuelSuggestionCategory {
//    case hydration
//    case electrolytes
//    case carbs
//    case protein
//    case calm
//    case light
//
//    func matches(_ item: FastFuelItem) -> Bool {
//        switch self {
//        case .hydration:
//            return item.title == "Water"
//
//        case .electrolytes:
//            return item.title == "Mineral Water" ||
//                   item.title == "Isotonic Drink"
//
//        case .carbs:
//            return item.title == "Banana" ||
//                   item.title == "Rice Cakes" ||
//                   item.title == "Oats" ||
//                   item.title == "Isotonic Drink" ||
//                   item.title == "Rice + Chicken Bowl" ||
//                   item.title == "Oats + Yogurt + Berries" ||
//                   item.title == "Recovery Shake"
//
//        case .protein:
//            return item.title == "Greek Yogurt" ||
//                   item.title == "Kefir 1%" ||
//                   item.title == "Protein Bar" ||
//                   item.title == "Rice + Chicken Bowl" ||
//                   item.title == "Oats + Yogurt + Berries" ||
//                   item.title == "Recovery Shake"
//
//        case .calm:
//            return item.title == "Herbal Tea"
//
//        case .light:
//            return item.title == "Water" ||
//                   item.title == "Banana" ||
//                   item.title == "Rice Cakes" ||
//                   item.title == "Kefir 1%"
//        }
//    }
//}
//
//// MARK: - Pool
//
//private extension FastFuelSuggestionServiceV3 {
//
//    func masterPool() -> [FastFuelItem] {
//        [
//            FastFuelItem(
//                imageName: "sports-drink",
//                title: "Isotonic Drink",
//                amount: "500 ml",
//                reason: "Carbs + electrolytes",
//                tags: [.fastCarb, .hydration, .electrolytes],
//                caloriesPer100g: 24,
//                proteinPer100g: 0,
//                carbsPer100g: 6,
//                fatsPer100g: 0,
//                standardWeightGrams: 500
//            ),
//
//            FastFuelItem(
//                imageName: "banana",
//                title: "Banana",
//                amount: "1 medium",
//                reason: "Easy carbs",
//                tags: [.fastCarb],
//                caloriesPer100g: 89,
//                proteinPer100g: 1.1,
//                carbsPer100g: 23,
//                fatsPer100g: 0.3,
//                standardWeightGrams: 120
//            ),
//
//            FastFuelItem(
//                imageName: "rice-cakes",
//                title: "Rice Cakes",
//                amount: "2 pieces",
//                reason: "Quick fuel",
//                tags: [.fastCarb],
//                caloriesPer100g: 387,
//                proteinPer100g: 8,
//                carbsPer100g: 82,
//                fatsPer100g: 3,
//                standardWeightGrams: 20
//            ),
//
//            FastFuelItem(
//                imageName: "oats",
//                title: "Oats",
//                amount: "40 g",
//                reason: "Steady fuel",
//                tags: [.complexCarb],
//                caloriesPer100g: 389,
//                proteinPer100g: 17,
//                carbsPer100g: 66,
//                fatsPer100g: 7,
//                standardWeightGrams: 40
//            ),
//
//            FastFuelItem(
//                imageName: "water-bottle",
//                title: "Water",
//                amount: "500 ml",
//                reason: "Hydration support",
//                tags: [.hydration],
//                caloriesPer100g: 0,
//                proteinPer100g: 0,
//                carbsPer100g: 0,
//                fatsPer100g: 0,
//                standardWeightGrams: 500
//            ),
//
//            FastFuelItem(
//                imageName: "ingredient-mineral-water",
//                title: "Mineral Water",
//                amount: "500 ml",
//                reason: "Minerals for hydration",
//                tags: [.hydration, .electrolytes],
//                caloriesPer100g: 0,
//                proteinPer100g: 0,
//                carbsPer100g: 0,
//                fatsPer100g: 0,
//                standardWeightGrams: 500
//            ),
//
//            FastFuelItem(
//                imageName: "protein-bar",
//                title: "Protein Bar",
//                amount: "1 bar",
//                reason: "Quick protein input",
//                tags: [.fastProtein],
//                caloriesPer100g: 380,
//                proteinPer100g: 30,
//                carbsPer100g: 25,
//                fatsPer100g: 10,
//                standardWeightGrams: 60
//            ),
//
//            FastFuelItem(
//                imageName: "greek-yogurt",
//                title: "Greek Yogurt",
//                amount: "200 g",
//                reason: "Recovery support",
//                tags: [.slowProtein, .fermented],
//                caloriesPer100g: 73,
//                proteinPer100g: 10,
//                carbsPer100g: 4,
//                fatsPer100g: 2,
//                standardWeightGrams: 200
//            ),
//
//            FastFuelItem(
//                imageName: "kefir",
//                title: "Kefir 1%",
//                amount: "1 glass",
//                reason: "Light recovery",
//                tags: [.electrolytes, .fermented, .slowProtein],
//                caloriesPer100g: 40,
//                proteinPer100g: 3,
//                carbsPer100g: 4,
//                fatsPer100g: 1,
//                standardWeightGrams: 250
//            ),
//
//            FastFuelItem(
//                imageName: "tea",
//                title: "Herbal Tea",
//                amount: "1 cup",
//                reason: "Calm evening support",
//                tags: [.hydration],
//                caloriesPer100g: 1,
//                proteinPer100g: 0,
//                carbsPer100g: 0.2,
//                fatsPer100g: 0,
//                standardWeightGrams: 250
//            ),
//
//            FastFuelItem(
//                imageName: "fork.knife",
//                title: "Rice + Chicken Bowl",
//                amount: "1 bowl",
//                reason: "Real recovery meal",
//                tags: [.slowProtein, .complexCarb],
//                caloriesPer100g: 155,
//                proteinPer100g: 13,
//                carbsPer100g: 18,
//                fatsPer100g: 3,
//                standardWeightGrams: 420
//            ),
//
//            FastFuelItem(
//                imageName: "fork.knife",
//                title: "Oats + Yogurt + Berries",
//                amount: "1 bowl",
//                reason: "Carbs + protein recovery",
//                tags: [.slowProtein, .complexCarb, .fermented],
//                caloriesPer100g: 130,
//                proteinPer100g: 8,
//                carbsPer100g: 18,
//                fatsPer100g: 3,
//                standardWeightGrams: 350
//            ),
//
//            FastFuelItem(
//                imageName: "takeoutbag.and.cup.and.straw.fill",
//                title: "Recovery Shake",
//                amount: "1 shake",
//                reason: "Fast protein + carbs",
//                tags: [.fastProtein, .fastCarb],
//                caloriesPer100g: 105,
//                proteinPer100g: 8,
//                carbsPer100g: 14,
//                fatsPer100g: 2,
//                standardWeightGrams: 400
//            )
//        ]
//    }
//
//    func unique(_ items: [FastFuelItem]) -> [FastFuelItem] {
//        var seen = Set<String>()
//        var result: [FastFuelItem] = []
//
//        for item in items {
//            guard !seen.contains(item.title) else { continue }
//            seen.insert(item.title)
//            result.append(item)
//        }
//
//        return result
//    }
//    
//    private func isAllowedByScenario(
//        item: FastFuelItem,
//        guidance: CoachGuidanceV3
//    ) -> Bool {
//        let load = activityLoad(from: guidance.phase)
//        let hour = Calendar.current.component(.hour, from: Date())
//        let isEvening = hour >= 18
//
//        switch guidance.phase {
//
//        case .active(let activity, let kind):
//            let isShort = activity.durationMinutes < 60
//
//            if item.title == "Herbal Tea" && !isEvening {
//                return false
//            }
//
//            if kind == .heat {
//                return item.title == "Water" ||
//                    item.title == "Mineral Water" ||
//                    item.title == "Banana" ||
//                    item.title == "Kefir 1%"
//            }
//
//            if kind == .recovery && load == .low && isShort {
//                return item.title == "Water"
//            }
//
//            if item.title == "Banana" && kind == .recovery && isShort {
//                return false
//            }
//
//            return true
//
//        case .preparing(let activity, let kind, _):
//            if item.title == "Herbal Tea" && !isEvening {
//                return false
//            }
//
//            if kind == .heat {
//                return item.title == "Water" ||
//                       item.title == "Mineral Water" ||
//                       item.title == "Banana"
//            }
//
//            if kind == .recovery && activity.durationMinutes < 60 {
//                return item.title == "Water"
//            }
//
//            if kind == .endurance || kind == .workout {
//                if item.title == "Greek Yogurt" ||
//                   item.title == "Kefir 1%" ||
//                   item.title == "Protein Bar" ||
//                   item.title == "Rice + Chicken Bowl" ||
//                   item.title == "Oats + Yogurt + Berries" ||
//                   item.title == "Recovery Shake" {
//                    return false
//                }
//            }
//
//            return true
//
//        case .recovering(let activity, let kind, _):
//            if item.title == "Herbal Tea" && !isEvening {
//                return false
//            }
//
//            if kind == .heat {
//                return item.title == "Water" ||
//                    item.title == "Mineral Water" ||
//                    item.title == "Banana" ||
//                    item.title == "Kefir 1%"
//            }
//
//            if kind == .recovery && activity.durationMinutes < 60 {
//                return item.title == "Water" ||
//                       item.title == "Kefir 1%" ||
//                       item.title == "Greek Yogurt"
//            }
//
//            return true
//
//        case .stable:
//            return false
//        }
//    }
//}
