import Foundation

/// Builds the two Frequently Used quick picks: most-logged + best fit for time/temperature.
enum QuickDrinkFrequentComposer {

    enum Badge: Equatable, Sendable {
        case mostUsed
        case morningBoost
        case forTheHeat
        case stayHydrated
        case warmUp
        case windDown
        case afternoonPick

        var localizationKey: String {
            switch self {
            case .mostUsed: return "today.quickLog.badge.mostUsed"
            case .morningBoost: return "today.quickLog.badge.morningBoost"
            case .forTheHeat: return "today.quickLog.badge.forTheHeat"
            case .stayHydrated: return "today.quickLog.badge.stayHydrated"
            case .warmUp: return "today.quickLog.badge.warmUp"
            case .windDown: return "today.quickLog.badge.windDown"
            case .afternoonPick: return "today.quickLog.badge.afternoonPick"
            }
        }
    }

    struct Pick: Equatable, Sendable {
        let item: QuickItem
        let badge: Badge
    }

    /// Up to two picks. Slot 1 = most used (when history exists).
    /// Slot 2 = best drink for current hour + outdoor temperature.
    static func picks(
        drinks: [QuickItem],
        usage: [String: QuickItemUsageStore.Entry],
        now: Date = Date(),
        temperatureCelsius: Double? = nil,
        calendar: Calendar = .current
    ) -> [Pick] {
        guard !drinks.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: drinks.map { ($0.id, $0) })

        var result: [Pick] = []
        var usedIDs = Set<String>()

        if let mostUsedID = mostUsedDrinkID(usage: usage, availableIDs: Set(byID.keys)),
           let item = byID[mostUsedID] {
            result.append(Pick(item: item, badge: .mostUsed))
            usedIDs.insert(item.id)
        }

        let hour = calendar.component(.hour, from: now)
        let suggestion = contextSuggestion(
            drinks: drinks,
            excluding: usedIDs,
            hour: hour,
            temperatureCelsius: temperatureCelsius
        )
        if let suggestion {
            result.append(suggestion)
        }

        // No history yet — still surface the context pick alone.
        return result
    }

    private static func mostUsedDrinkID(
        usage: [String: QuickItemUsageStore.Entry],
        availableIDs: Set<String>
    ) -> String? {
        usage
            .filter { $0.value.count >= 1 && availableIDs.contains($0.key) }
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.value.lastUsedAt > rhs.value.lastUsedAt
                }
                return lhs.value.count > rhs.value.count
            }
            .first?
            .key
    }

    private static func contextSuggestion(
        drinks: [QuickItem],
        excluding: Set<String>,
        hour: Int,
        temperatureCelsius: Double?
    ) -> Pick? {
        let rankedIDs = preferredDrinkIDs(hour: hour, temperatureCelsius: temperatureCelsius)
        let candidates = rankedIDs.compactMap { id in drinks.first(where: { $0.id == id }) }
            .filter { !excluding.contains($0.id) }

        guard let item = candidates.first else {
            return drinks.first(where: { !excluding.contains($0.id) }).map {
                Pick(item: $0, badge: .stayHydrated)
            }
        }

        return Pick(item: item, badge: badge(for: item.id, hour: hour, temperatureCelsius: temperatureCelsius))
    }

    /// Ordered preference list for the current context.
    private static func preferredDrinkIDs(hour: Int, temperatureCelsius: Double?) -> [String] {
        let temp = temperatureCelsius
        let isHot = (temp ?? 20) >= 28
        let isWarm = (temp ?? 20) >= 22
        let isCold = (temp ?? 20) <= 8

        switch hour {
        case 5..<10:
            // Morning — caffeine first; heat flips to iced / water.
            if isHot {
                return ["drink_iced_coffee", "drink_water", "drink_tonic", "drink_coffee", "drink_tea"]
            }
            if isCold {
                return ["drink_coffee", "drink_tea", "drink_espresso", "drink_milk", "drink_water"]
            }
            return ["drink_coffee", "drink_espresso", "drink_tea", "drink_water", "drink_orange_juice"]

        case 10..<14:
            // Late morning / midday.
            if isHot {
                return ["drink_water", "drink_iced_coffee", "drink_tonic", "drink_orange_juice", "drink_tea"]
            }
            if isCold {
                return ["drink_tea", "drink_coffee", "drink_milk", "drink_water"]
            }
            return ["drink_water", "drink_tea", "drink_coffee", "drink_orange_juice"]

        case 14..<18:
            // Afternoon — prioritize cooling when warm/hot.
            if isHot {
                return ["drink_iced_coffee", "drink_water", "drink_tonic", "drink_orange_juice", "drink_tea"]
            }
            if isWarm {
                return ["drink_water", "drink_iced_coffee", "drink_tonic", "drink_tea"]
            }
            if isCold {
                return ["drink_tea", "drink_coffee", "drink_milk", "drink_water"]
            }
            return ["drink_water", "drink_tea", "drink_coffee", "drink_tonic"]

        case 18..<22:
            // Evening — soften caffeine; hydrate or warm tea.
            if isHot {
                return ["drink_water", "drink_tonic", "drink_tea", "drink_iced_coffee"]
            }
            if isCold {
                return ["drink_tea", "drink_milk", "drink_water", "drink_kefir"]
            }
            return ["drink_tea", "drink_water", "drink_milk", "drink_kefir"]

        default:
            // Night — calm hydration.
            if isHot {
                return ["drink_water", "drink_tonic", "drink_tea"]
            }
            return ["drink_water", "drink_tea", "drink_milk"]
        }
    }

    private static func badge(
        for drinkID: String,
        hour: Int,
        temperatureCelsius: Double?
    ) -> Badge {
        let temp = temperatureCelsius ?? 20
        if temp >= 28 {
            if drinkID == "drink_water" || drinkID == "drink_tonic" {
                return .forTheHeat
            }
            if drinkID.contains("iced") {
                return .forTheHeat
            }
            return .stayHydrated
        }
        if temp <= 8 {
            return .warmUp
        }
        switch hour {
        case 5..<10:
            return .morningBoost
        case 14..<18:
            return .afternoonPick
        case 18..<23:
            return .windDown
        default:
            return .stayHydrated
        }
    }
}
