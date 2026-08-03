import Foundation

/// Snack Frequent picks: most used + best fit for time of day.
enum QuickSnackFrequentComposer {

    enum Badge: Equatable, Sendable {
        case mostUsed
        case morningFuel
        case afternoonPick
        case eveningTreat
        case lightBite

        var localizationKey: String {
            switch self {
            case .mostUsed: return "today.quickLog.badge.mostUsed"
            case .morningFuel: return "today.quickLog.badge.morningFuel"
            case .afternoonPick: return "today.quickLog.badge.afternoonPick"
            case .eveningTreat: return "today.quickLog.badge.eveningTreat"
            case .lightBite: return "today.quickLog.badge.lightBite"
            }
        }

        var symbolName: String {
            switch self {
            case .mostUsed: return "star.fill"
            case .morningFuel: return "sunrise.fill"
            case .afternoonPick: return "sun.max.fill"
            case .eveningTreat: return "moon.stars.fill"
            case .lightBite: return "leaf.fill"
            }
        }
    }

    struct Pick: Equatable, Sendable {
        let item: QuickItem
        let badge: Badge
    }

    static func picks(
        snacks: [QuickItem],
        usage: [String: QuickItemUsageStore.Entry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Pick] {
        guard !snacks.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: snacks.map { ($0.id, $0) })
        var result: [Pick] = []
        var used = Set<String>()

        let rankedSnackUsage = usage
            .filter { $0.value.count >= 1 && byID[$0.key] != nil }
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.value.lastUsedAt > rhs.value.lastUsedAt
                }
                return lhs.value.count > rhs.value.count
            }

        if let mostID = rankedSnackUsage.first?.key,
           let item = byID[mostID] {
            result.append(Pick(item: item, badge: .mostUsed))
            used.insert(item.id)
        }

        let hour = calendar.component(.hour, from: now)
        let preferred = preferredSnackIDs(hour: hour)
        if let item = preferred.compactMap({ id in snacks.first(where: { $0.id == id }) })
            .first(where: { !used.contains($0.id) }) {
            result.append(Pick(item: item, badge: badge(for: hour)))
        } else if let fallback = snacks.first(where: { !used.contains($0.id) }) {
            result.append(Pick(item: fallback, badge: .lightBite))
        }

        return result
    }

    private static func preferredSnackIDs(hour: Int) -> [String] {
        switch hour {
        case 5..<11:
            return ["snack_greek_yogurt", "snack_banana", "snack_apple", "snack_protein_bar"]
        case 11..<15:
            return ["snack_apple", "snack_protein_bar", "snack_rice_cakes", "snack_banana", "snack_mixed_nuts"]
        case 15..<18:
            return ["snack_mixed_nuts", "snack_protein_bar", "snack_rice_cakes", "snack_blueberries", "snack_apple"]
        case 18..<22:
            return ["snack_dark_chocolate", "snack_greek_yogurt", "snack_strawberries", "snack_cookies", "snack_mixed_nuts"]
        default:
            return ["snack_greek_yogurt", "snack_banana", "snack_apple", "snack_mixed_nuts"]
        }
    }

    private static func badge(for hour: Int) -> Badge {
        switch hour {
        case 5..<11: return .morningFuel
        case 11..<18: return .afternoonPick
        case 18..<23: return .eveningTreat
        default: return .lightBite
        }
    }
}

/// Meal Frequent picks from catalog usage history.
enum QuickMealFrequentComposer {

    enum Badge: Equatable, Sendable {
        case mostEaten
        case lightAndFresh

        var localizationKey: String {
            switch self {
            case .mostEaten: return "today.quickLog.badge.mostEaten"
            case .lightAndFresh: return "today.quickLog.badge.lightAndFresh"
            }
        }

        var symbolName: String {
            switch self {
            case .mostEaten: return "star.fill"
            case .lightAndFresh: return "leaf.fill"
            }
        }
    }

    struct Pick: Equatable, Sendable {
        let meal: Meals
        let badge: Badge
    }

    static func picks(
        meals: [Meals],
        usage: [String: QuickItemUsageStore.Entry],
        limit: Int = 2
    ) -> [Pick] {
        guard !meals.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: meals.map { ($0.id, $0) })

        let rankedIDs = usage
            .filter { $0.value.count >= 1 && byID[$0.key] != nil }
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.value.lastUsedAt > rhs.value.lastUsedAt
                }
                return lhs.value.count > rhs.value.count
            }
            .map(\.key)

        var picks: [Pick] = []
        var used = Set<String>()

        if let firstID = rankedIDs.first, let meal = byID[firstID] {
            picks.append(Pick(meal: meal, badge: .mostEaten))
            used.insert(meal.id)
        }

        if picks.count < limit {
            let secondID = rankedIDs.dropFirst().first
            if let secondID, let meal = byID[secondID], !used.contains(meal.id) {
                picks.append(Pick(meal: meal, badge: .lightAndFresh))
                used.insert(meal.id)
            }
        }

        if picks.isEmpty {
            return Array(meals.prefix(limit)).enumerated().map { index, meal in
                Pick(meal: meal, badge: index == 0 ? .mostEaten : .lightAndFresh)
            }
        }

        while picks.count < limit, let next = meals.first(where: { !used.contains($0.id) }) {
            picks.append(Pick(meal: next, badge: picks.isEmpty ? .mostEaten : .lightAndFresh))
            used.insert(next.id)
        }

        // Force mock-stable badges by slot order.
        return picks.enumerated().map { index, pick in
            Pick(meal: pick.meal, badge: index == 0 ? .mostEaten : .lightAndFresh)
        }
    }
}
