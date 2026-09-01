import Foundation

/// Shared outdoor suitability for Weather UI semantics and Morning Adjustments.
/// Derived from WeatherKit condition + wind + precip + temperature/feelsLike —
/// not a single arbitrary wind speed cutover.
enum OutdoorSuitability: String, Codable, Sendable, Equatable {
    case good
    case acceptable
    case adverse
    case unsafe

    /// Outdoor creates (walk / easy run) are hard-gated only when unsafe.
    var allowsOutdoorCreate: Bool { self != .unsafe }

    /// Adverse/unsafe outdoor loses to indoor recovery families in ranking.
    var outdoorRankingPenalty: Int {
        switch self {
        case .good: return 0
        case .acceptable: return 4
        case .adverse: return 18
        case .unsafe: return 40
        }
    }
}

/// How today's open plan relates to recovery movement invent.
enum ExistingPlanMovementSuitability: String, Codable, Sendable, Equatable {
    /// No open endurance / recovery / walk / cycle / run / HIIT / mobility.
    case none
    /// Light recovery already present (walk / stretch / yoga / breathing / short recovery).
    case suitableLight
    /// Mild aerobic that may need shortening on recover (e.g. easy run).
    case borderline
    /// Hard / elevated session inappropriate as the day's recovery movement.
    case inappropriateHard
}

enum OutdoorSuitabilityResolver {

    /// Single assessment shared by Morning Adjustments and weather risk tokens.
    static func assess(from summary: WeekFitWeatherSummary?) -> (
        suitability: OutdoorSuitability,
        riskToken: ProposalWeatherRiskToken
    ) {
        guard let summary else {
            return (.acceptable, .unavailable)
        }

        let precip = summary.precipitationChance ?? 0
        let tempC = summary.temperature.value
        let feelsC = summary.feelsLike.value
        let windKmh = summary.windSpeed.value
        let visibilityKm = summary.visibilityKilometers
        let condition = summary.condition

        // --- Unsafe (hard outdoor gate) ---
        if condition == .storm || precip >= 70 {
            return (.unsafe, .storm)
        }

        // --- Adverse drivers (aligned with WeekFitWeatherRelevance priorities) ---
        var adverseReasons: [ProposalWeatherRiskToken] = []

        if condition == .fog || (visibilityKm ?? 20) < 1.2 {
            adverseReasons.append(.cold)
        }
        if precip >= 55 || condition == .rain || condition == .snow {
            adverseReasons.append(.precip)
        }
        if tempC >= 33 {
            adverseReasons.append(.heat)
        }
        // Explicit WeatherKit "Windy" must never classify as calm/good — regardless of speed.
        if condition == .windy || windKmh >= 40 {
            adverseReasons.append(.wind)
        }
        if tempC <= 0 || (feelsC <= 2 && windKmh >= 25) {
            adverseReasons.append(.cold)
        }

        if let primary = primaryRisk(adverseReasons) {
            return (.adverse, primary)
        }

        // --- Good vs acceptable ---
        let comfortableTemp = tempC >= 12 && tempC <= 26
        let lightWind = windKmh < 25
        let dry = precip < 30
        if (condition == .clear || condition == .partlyCloudy),
           comfortableTemp, lightWind, dry {
            return (.good, .calm)
        }

        return (.acceptable, .calm)
    }

    static func suitability(from summary: WeekFitWeatherSummary?) -> OutdoorSuitability {
        assess(from: summary).suitability
    }

    private static func primaryRisk(_ reasons: [ProposalWeatherRiskToken]) -> ProposalWeatherRiskToken? {
        let order: [ProposalWeatherRiskToken] = [.precip, .heat, .wind, .cold]
        for token in order where reasons.contains(token) {
            return token
        }
        return reasons.first
    }
}

enum ExistingPlanMovementSuitabilityClassifier {

    static func classify(
        todayOpen: [CoachPlannedActivitySnapshot],
        strategy: DailyStrategy
    ) -> ExistingPlanMovementSuitability {
        let movement = todayOpen.filter { isMovementRelevant($0) }
        guard !movement.isEmpty else { return .none }

        if movement.contains(where: { isSuitableLightRecovery($0) }) {
            return .suitableLight
        }

        if strategy == .recover || strategy == .protectTomorrow {
            if movement.contains(where: {
                CoachActivityClassifier.isElevatedTrainingLoad($0)
                    || CoachActivityClassifier.isSeriousTraining($0)
            }) {
                return .inappropriateHard
            }
            return .borderline
        }

        // Maintain/train: any open movement suppresses invent.
        return .suitableLight
    }

    static func isMovementRelevant(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        let family = CoachActivityClassifier.family(for: activity)
        let type = CoachActivityClassifier.type(for: activity)
        return family == .endurance || family == .recovery
            || type == .walk || type == .cycling || type == .running || type == .hiit
            || type == .yoga || type == .stretching || type == .breathing
    }

    static func isSuitableLightRecovery(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        let type = CoachActivityClassifier.type(for: activity)
        if type == .yoga || type == .stretching || type == .breathing {
            return true
        }
        if type == .walk {
            return activity.durationMinutes <= 45
        }
        if CoachActivityClassifier.family(for: activity) == .recovery,
           activity.durationMinutes <= 40,
           !CoachActivityClassifier.isElevatedTrainingLoad(activity) {
            return true
        }
        return false
    }
}
