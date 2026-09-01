import Foundation

/// Coarse, privacy-safe weather risk for morning proposals (no raw temp in analytics).
enum ProposalWeatherRiskToken: String, Codable, Sendable, Equatable {
    case unavailable
    case calm
    case precip
    case storm
    case heat
    case wind
    case cold

    var isAdverse: Bool {
        switch self {
        case .precip, .storm, .heat, .wind, .cold:
            return true
        case .unavailable, .calm:
            return false
        }
    }
}

enum ProposalWeatherRisk {

    static func resolve(from summary: WeekFitWeatherSummary?) -> ProposalWeatherRiskToken {
        // Keep risk tokens and OutdoorSuitability on one assessment so UI "Windy"
        // cannot resolve as calm for Morning Adjustments.
        OutdoorSuitabilityResolver.assess(from: summary).riskToken
    }

    static func outdoorSuitability(from summary: WeekFitWeatherSummary?) -> OutdoorSuitability {
        OutdoorSuitabilityResolver.assess(from: summary).suitability
    }
}

enum ProposalOutdoorClassifier {

    /// Best-effort: endurance outdoors + hike/outdoor keywords. Gym strength is indoor.
    static func isOutdoorLikely(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        switch CoachActivityClassifier.type(for: activity) {
        case .running, .cycling, .walk, .hiit:
            return true
        case .swimming, .sauna, .stretching, .yoga, .breathing,
             .upperBody, .lowerBody, .core, .fullBody, .tennis, .squash, .none:
            break
        }

        let blob = "\(activity.title) \(activity.type) \(activity.icon)".lowercased()
        let outdoorTokens = [
            "hike", "hiking", "trail", "outdoor", "outside",
            "run", "jog", "bike", "cycling", "ride",
            "прогул", "бег", "велос", "хайк", "улиц",
        ]
        return outdoorTokens.contains { blob.contains($0) }
    }
}
