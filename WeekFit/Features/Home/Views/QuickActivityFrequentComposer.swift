import Foundation
import SwiftUI

/// Frequent picks for Activity Start: most used + context-aware “For now”
/// (recovery band × weather × time of day).
enum QuickActivityFrequentComposer {

    enum Badge: Equatable, Sendable {
        case mostUsed
        case forNow
        case forTheHeat
        case easyDay
        case windDown

        var localizationKey: String {
            switch self {
            case .mostUsed: return "today.quickLog.badge.mostUsed"
            case .forNow: return "home.activityStart.badge.forNow"
            case .forTheHeat: return "today.quickLog.badge.forTheHeat"
            case .easyDay: return "home.activityStart.badge.easyDay"
            case .windDown: return "today.quickLog.badge.windDown"
            }
        }

        var symbolName: String {
            switch self {
            case .mostUsed: return "star.fill"
            case .forNow: return "clock.fill"
            case .forTheHeat: return "sun.max.fill"
            case .easyDay: return "leaf.fill"
            case .windDown: return "moon.stars.fill"
            }
        }
    }

    struct Pick: Equatable, Sendable {
        let option: PlannerOption
        let badge: Badge
    }

    static func picks(
        options: [PlannerOption],
        usage: [String: QuickActivityUsageStore.Entry],
        weatherRisk: ProposalWeatherRiskToken = .unavailable,
        recoveryBand: CoachRecoveryBand? = nil,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 2
    ) -> [Pick] {
        guard !options.isEmpty else { return [] }
        let byImage = Dictionary(uniqueKeysWithValues: options.map { ($0.imageName, $0) })
        var picks: [Pick] = []
        var used = Set<String>()

        let ranked = usage
            .filter { $0.value.count >= 1 && byImage[$0.key] != nil }
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.value.lastUsedAt > rhs.value.lastUsedAt
                }
                return lhs.value.count > rhs.value.count
            }

        if let most = ranked.first, let option = byImage[most.key] {
            picks.append(Pick(option: option, badge: .mostUsed))
            used.insert(option.imageName)
        }

        let hour = calendar.component(.hour, from: now)
        let preferred = preferredKeys(
            hour: hour,
            weatherRisk: weatherRisk,
            recoveryBand: recoveryBand,
            isRecoveryCatalog: options.contains { $0.imageName.hasPrefix("recovery-") }
        )
        let contextBadge = badge(
            hour: hour,
            weatherRisk: weatherRisk,
            recoveryBand: recoveryBand
        )

        if let key = preferred.first(where: { !used.contains($0) && byImage[$0] != nil }),
           let option = byImage[key] {
            picks.append(Pick(option: option, badge: contextBadge))
            used.insert(option.imageName)
        } else if let fallback = options.first(where: { !used.contains($0.imageName) }) {
            picks.append(Pick(option: fallback, badge: contextBadge))
            used.insert(fallback.imageName)
        }

        if picks.isEmpty {
            return options.prefix(limit).enumerated().map { index, option in
                Pick(option: option, badge: index == 0 ? .mostUsed : .forNow)
            }
        }

        while picks.count < min(limit, options.count),
              let next = options.first(where: { !used.contains($0.imageName) }) {
            picks.append(Pick(option: next, badge: .forNow))
            used.insert(next.imageName)
        }

        return Array(picks.prefix(limit))
    }

    private static func badge(
        hour: Int,
        weatherRisk: ProposalWeatherRiskToken,
        recoveryBand: CoachRecoveryBand?
    ) -> Badge {
        if weatherRisk == .heat { return .forTheHeat }
        if recoveryBand == .low { return .easyDay }
        if hour >= 18 { return .windDown }
        return .forNow
    }

    private static func preferredKeys(
        hour: Int,
        weatherRisk: ProposalWeatherRiskToken,
        recoveryBand: CoachRecoveryBand?,
        isRecoveryCatalog: Bool
    ) -> [String] {
        if isRecoveryCatalog {
            if recoveryBand == .low || hour >= 18 {
                return ["recovery-walk", "recovery-stretch", "recovery-yoga", "recovery-breathing", "recovery-sauna"]
            }
            if weatherRisk == .heat {
                return ["recovery-stretch", "recovery-yoga", "recovery-walk", "recovery-breathing"]
            }
            return ["recovery-walk", "recovery-yoga", "recovery-stretch", "recovery-sauna", "recovery-breathing"]
        }

        if recoveryBand == .low {
            return ["workout-swimming", "workout-cycling", "workout-hiking", "workout-running", "workout-strength"]
        }

        switch weatherRisk {
        case .heat:
            return ["workout-swimming", "workout-strength", "workout-hiit", "workout-fullbody", "workout-cycling"]
        case .precip, .storm, .cold, .wind:
            return ["workout-strength", "workout-fullbody", "workout-hiit", "workout-core", "workout-swimming"]
        case .calm, .unavailable:
            break
        }

        switch hour {
        case 5..<10:
            return ["workout-running", "workout-cycling", "workout-strength", "workout-swimming", "workout-hiit"]
        case 10..<14:
            return ["workout-strength", "workout-running", "workout-cycling", "workout-hiit", "workout-fullbody"]
        case 14..<18:
            return ["workout-hiit", "workout-fullbody", "workout-tennis", "workout-running", "workout-cycling"]
        case 18..<22:
            return ["workout-core", "workout-strength", "workout-swimming", "workout-running"]
        default:
            return ["workout-strength", "workout-core", "workout-swimming", "workout-cycling"]
        }
    }
}

/// Display meta for Activity list rows (category color + detail chip).
enum ActivityOptionPresentation {

    enum Category: String {
        case cardio
        case endurance
        case strength
        case highIntensity
        case mobility
        case lightRecovery
        case relax
        case calm

        var localizationKey: String {
            switch self {
            case .cardio: return "home.activityStart.category.cardio"
            case .endurance: return "home.activityStart.category.endurance"
            case .strength: return "home.activityStart.category.strength"
            case .highIntensity: return "home.activityStart.category.highIntensity"
            case .mobility: return "home.activityStart.category.mobility"
            case .lightRecovery: return "home.activityStart.category.lightRecovery"
            case .relax: return "home.activityStart.category.relax"
            case .calm: return "home.activityStart.category.calm"
            }
        }

        var color: Color {
            switch self {
            case .cardio: return Color(red: 0.20, green: 0.72, blue: 0.42)
            case .endurance: return Color(red: 0.28, green: 0.55, blue: 0.92)
            case .strength: return Color(red: 0.55, green: 0.40, blue: 0.86)
            case .highIntensity: return Color(red: 0.92, green: 0.42, blue: 0.32)
            case .mobility: return Color(red: 0.35, green: 0.70, blue: 0.55)
            case .lightRecovery: return Color(red: 0.32, green: 0.68, blue: 0.78)
            case .relax: return Color(red: 0.86, green: 0.52, blue: 0.28)
            case .calm: return Color(red: 0.48, green: 0.55, blue: 0.86)
            }
        }
    }

    struct DetailChip: Equatable {
        let symbol: String
        let localizationKey: String
    }

    static func category(for option: PlannerOption) -> Category {
        switch option.subtitle.lowercased() {
        case "cardio": return .cardio
        case "endurance": return .endurance
        case "strength": return .strength
        case "high intensity": return .highIntensity
        case "mobility": return .mobility
        case "light recovery": return .lightRecovery
        case "relax": return .relax
        case "calm": return .calm
        default:
            let title = option.title.lowercased()
            if title.contains("hiit") || title.contains("squash") { return .highIntensity }
            if title.contains("run") { return .cardio }
            if title.contains("strength") || title.contains("body") || title.contains("core") { return .strength }
            return .endurance
        }
    }

    static func intensityLabelKey(for option: PlannerOption) -> String {
        switch category(for: option) {
        case .highIntensity: return "home.activityStart.intensity.high"
        case .strength: return "home.activityStart.intensity.strength"
        case .cardio, .endurance: return "home.activityStart.intensity.moderate"
        case .mobility, .lightRecovery, .relax, .calm: return "home.activityStart.intensity.easy"
        }
    }

    static func detailChip(for option: PlannerOption) -> DetailChip {
        let title = option.title.lowercased()
        let image = option.imageName.lowercased()

        if image.contains("hiit") || title.contains("interval") || title.contains("squash") {
            return DetailChip(symbol: "heart.fill", localizationKey: "home.activityStart.chip.hrZone")
        }
        if image.contains("hiking") || title.contains("hike") {
            return DetailChip(symbol: "mountain.2.fill", localizationKey: "home.activityStart.chip.outdoor")
        }
        if image.contains("fullbody") || image.contains("running") || image.contains("swimming") {
            return DetailChip(symbol: "drop.fill", localizationKey: "home.activityStart.chip.fullBody")
        }
        if image.contains("strength") || image.contains("upper") || image.contains("lower") || image.contains("core") {
            return DetailChip(symbol: "dumbbell.fill", localizationKey: "home.activityStart.chip.muscleFocus")
        }
        if image.contains("cycling") || image.contains("tennis") {
            return DetailChip(symbol: "heart.fill", localizationKey: "home.activityStart.chip.hrZone")
        }
        if image.contains("stretch") || image.contains("yoga") {
            return DetailChip(symbol: "leaf.fill", localizationKey: "home.activityStart.chip.flexibility")
        }
        if image.contains("walk") {
            return DetailChip(symbol: "figure.walk", localizationKey: "home.activityStart.chip.easyPace")
        }
        if image.contains("sauna") {
            return DetailChip(symbol: "flame.fill", localizationKey: "home.activityStart.chip.heat")
        }
        if image.contains("breath") {
            return DetailChip(symbol: "wind", localizationKey: "home.activityStart.chip.reset")
        }
        return DetailChip(symbol: "sparkles", localizationKey: "home.activityStart.chip.recommended")
    }
}
