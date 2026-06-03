import Foundation

// MARK: - Production Session Message Builder

enum CoachSessionMessageBuilder {

    static func messages(
        scenario: CoachActivityScenario,
        fallback: [String],
        maxItems: Int = 3
    ) -> [String] {

        let profile = CoachActivityProfileResolver.resolve(scenario: scenario)
        let messages = profileMessages(
            profile: profile,
            stage: scenario.stage,
            scenario: scenario
        )

        let selected = messages.isEmpty ? fallback : messages

        return Array(unique(selected).prefix(maxItems))
    }
}

// MARK: - Messages

private extension CoachSessionMessageBuilder {

    static func profileMessages(
        profile: CoachFuelingActivityProfile,
        stage: CoachActivityStage,
        scenario: CoachActivityScenario
    ) -> [String] {

        switch (profile, stage) {

        case (.breathing, .before):
            return [
                "Sit or lie down comfortably",
                "Let the exhale become slower",
                "Do not force the breath"
            ]

        case (.breathing, .during):
            return [
                "Keep the breath comfortable",
                "Make the exhale gentle",
                "Return calmly if your mind wanders"
            ]

        case (.breathing, .after):
            return [
                "Keep the recovery effect",
                "Continue calmly",
                "Avoid jumping back into stress"
            ]

        // MARK: Running

        case (.endurance(.running), .before):
            if isVeryLongSession(scenario) {
                return [
                    "Keep a pace you could hold all day",
                    "Avoid pushing early hills",
                    "Finish with energy left"
                ]
            }

            return [
                "Start slower than you think",
                "Keep a pace where you can talk",
                "Finish feeling like you could do more"
            ]

        case (.endurance(.running), .during):
            return [
                "Keep the effort steady",
                "Relax your shoulders",
                "Do not chase speed today"
            ]

        case (.endurance(.running), .after):
            return [
                "Walk for a few minutes",
                "Let your breathing settle",
                "Keep the rest of the day easy"
            ]

        // MARK: Cycling

        case (.endurance(.cycling), .before):
            if isVeryLongSession(scenario) {
                return [
                    "Keep a pace you could hold all day",
                    "Avoid pushing on climbs too early",
                    "Finish with energy left"
                ]
            }

            return [
                "Ride easy for the first 10 min",
                "Stay comfortable early",
                "Save energy for the second half"
            ]

        case (.endurance(.cycling), .during):
            if isVeryLongSession(scenario) {
                return [
                    "Keep pressure smooth",
                    "Avoid sudden hard pushes",
                    "Finish stronger than you started"
                ]
            }

            return [
                "Keep pressure smooth",
                "Avoid sudden hard pushes",
                "Finish with energy left"
            ]

        case (.endurance(.cycling), .after):
            return [
                "Spin or walk easy for a few minutes",
                "Let your legs settle",
                "Keep the evening easy"
            ]

        // MARK: Tennis

        case (.racket(.tennis), .before):
            return [
                "Stay light on your feet",
                "Play with control first",
                "Use the first games to find rhythm"
            ]

        case (.racket(.tennis), .during):
            return [
                "Relax between points",
                "Do not rush the next shot",
                "Win with consistency first"
            ]

        case (.racket(.tennis), .after):
            return [
                "Let the body calm down",
                "Protect sleep tonight",
                "Avoid another hard session"
            ]

        // MARK: Squash

        case (.racket(.squash), .before):
            return [
                "Warm up before the first rally",
                "Control the first games",
                "Save energy for the finish"
            ]

        case (.racket(.squash), .during):
            return [
                "Slow down between rallies",
                "Control your breathing",
                "Do not make every rally all-out"
            ]

        case (.racket(.squash), .after):
            return [
                "Cool down gradually",
                "Keep the rest of the day easy",
                "Avoid another hard workout"
            ]

        // MARK: Strength

        case (.strength, .before):
            return [
                "Start with lighter warm-up sets",
                "Focus on clean technique",
                "Leave energy for the final sets"
            ]

        case (.strength, .during):
            return [
                "Keep good form on every set",
                "Leave 1–2 reps in reserve",
                "Stop before technique breaks down"
            ]

        case (.strength, .after):
            return [
                "Walk for 5–10 min",
                "Let your heart rate settle",
                "Avoid adding extra workouts"
            ]

        // MARK: Heat

        case (.heat, .before):
            return [
                "Keep the session comfortable",
                "Do not chase discomfort",
                "Stop before it feels stressful"
            ]

        case (.heat, .during):
            return [
                "Leave if you feel dizzy",
                "Do not stay longer than feels good",
                "Focus on relaxing"
            ]

        case (.heat, .after):
            return [
                "Let your body settle",
                "Keep the evening calm",
                "Avoid hard training after heat"
            ]

        // MARK: Recovery

        case (.recovery, .before):
            return [
                "Keep the pace easy",
                "Move like this is recovery",
                "Finish feeling better, not tired"
            ]

        case (.recovery, .during):
            return [
                "Stay relaxed",
                "Breathe normally",
                "Do not turn this into training"
            ]

        case (.recovery, .after):
            return [
                "Keep the recovery effect",
                "Continue calmly",
                "Avoid adding load"
            ]

        // MARK: General endurance / racket / other

        case (.endurance(.general), .before):
            return [
                "Start easy",
                "Keep the effort comfortable",
                "Finish with energy left"
            ]

        case (.endurance(.general), .during):
            return [
                "Keep effort steady",
                "Stay relaxed",
                "Avoid pushing too early"
            ]

        case (.endurance(.general), .after):
            return [
                "Let your breathing settle",
                "Keep the rest of the day easy",
                "Avoid extra intensity"
            ]

        case (.racket(.general), .before):
            return [
                "Warm up properly",
                "Play with control first",
                "Build rhythm gradually"
            ]

        case (.racket(.general), .during):
            return [
                "Stay relaxed",
                "Do not rush",
                "Focus on consistency"
            ]

        case (.racket(.general), .after):
            return [
                "Let the body calm down",
                "Keep the rest of the day easy",
                "Avoid extra intensity"
            ]

        case (.other, .before):
            return [
                "Start easy",
                "Stay controlled",
                "Keep the plan simple"
            ]

        case (.other, .during):
            return [
                "Keep effort controlled",
                "Stay comfortable",
                "Finish calmly"
            ]

        case (.other, .after):
            return [
                "Return to the plan",
                "Keep the next step simple",
                "Stay consistent"
            ]

        case (_, .stable):
            return []
        }
    }

    static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }

            let key = clean.lowercased()
            guard !seen.contains(key) else { continue }

            seen.insert(key)
            result.append(clean)
        }

        return result
    }
}

// MARK: - Helpers

private extension CoachSessionMessageBuilder {

    static func durationMinutes(_ scenario: CoachActivityScenario) -> Int {
        guard let activity = scenario.activity else {
            return 0
        }

        return max(activity.effectiveDurationMinutes, activity.durationMinutes)
    }

    static func isVeryLongSession(_ scenario: CoachActivityScenario) -> Bool {
        durationMinutes(scenario) >= 150 ||
        scenario.durationBucket == .over90
    }
}
