import Foundation

// MARK: - Activity Profile Resolver

enum CoachActivityProfileResolver {

    static func resolve(
        scenario: CoachActivityScenario
    ) -> CoachFuelingActivityProfile {

        let text = "\(scenario.activity?.title ?? "") \(scenario.activity?.type ?? "")"
            .lowercased()

        if containsAny(text, [
            "breathing",
            "breathwork",
            "breath",
            "meditation",
            "mindfulness",
            "relaxation",
            "nervous system",
            "calm"
        ]) {
            return .breathing
        }

        if containsAny(text, ["running", "run", "jog"]) {
            return .endurance(.running)
        }

        if containsAny(text, ["cycling", "cycle", "bike", "ride", "biking"]) {
            return .endurance(.cycling)
        }

        if text.contains("tennis") {
            return .racket(.tennis)
        }

        if text.contains("squash") {
            return .racket(.squash)
        }

        if containsAny(text, [
            "upper body",
            "lower body",
            "strength",
            "gym",
            "lifting",
            "weights",
            "dumbbell",
            "barbell",
            "push",
            "pull",
            "legs"
        ]) {
            return .strength
        }

        if containsAny(text, ["sauna", "heat", "hot yoga"]) {
            return .heat
        }

        if containsAny(text, [
            "walk",
            "walking",
            "hike",
            "stretch",
            "mobility",
            "yoga"
        ]) {
            return .recovery
        }

        if scenario.archetype == .endurance {
            return .endurance(.general)
        }

        if scenario.archetype == .performance {
            return .strength
        }

        if scenario.archetype == .heat {
            return .heat
        }

        if scenario.archetype == .recovery {
            return .recovery
        }

        return .other
    }

    private static func containsAny(
        _ text: String,
        _ needles: [String]
    ) -> Bool {
        needles.contains { text.contains($0) }
    }
}
