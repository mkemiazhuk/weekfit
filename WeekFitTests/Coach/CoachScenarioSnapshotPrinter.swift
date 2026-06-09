import Foundation

struct CoachScenarioInputSnapshot {
    let currentTime: String
    let sleepInput: String
    let mealsInput: [String]
    let drinksInput: [String]
    let plannedActivities: [String]
    let activeActivities: [String]
    let completedActivities: [String]
    let cancelledActivities: [String]
    let partialActivities: [String]
    let saunaState: String
    let recoveryInputs: String
    let hydrationInputs: String
    let deletedItems: [String]
    let rawStoredRecords: [String]
}

struct CoachScenarioOutputSnapshot {
    let todayCards: [String]
    let todayHeadline: String
    let coachHeadline: String
    let coachNextAction: String
    let coachExplanation: String
    let readinessScore: Int
    let readinessBreakdown: String
    let recoveryState: String
    let primaryLimiter: String
    let confidenceAndMissingDataState: String
    let hydrationPrompt: String
    let nutritionPrompt: String
    let activityRecommendation: String
    let tomorrowProtection: String
    let plannerReservations: [String]
    let decisionTrace: String
    let recommendationTrace: String
    let plannerTrace: String
}

struct CoachDecisionAudit {
    let rawInputs: [String]
    let normalizedValues: [String]
    let scoringBreakdown: [String]
    let finalDecision: [String]
}

struct CoachReadinessScoreBreakdown {
    let raw: Int
    let cap: Int?
    let capReason: String?
    let final: Int
    let contributions: [String]

    var debugDescription: String {
        "raw=\(raw), cap=\(cap.map(String.init) ?? "none"), capReason=\(capReason ?? "none"), final=\(final), contributions=\(contributions)"
    }
}

enum CoachScenarioSnapshotPrinter {
    static let logFileURL = URL(fileURLWithPath: "/tmp/WeekFitTodayCoachStressScenarioSnapshots.txt")

    static func resetLogFile() {
        try? FileManager.default.removeItem(at: logFileURL)
    }

    static func printCheckpoint(
        name: String,
        time: Date,
        input: CoachScenarioInputSnapshot,
        output: CoachScenarioOutputSnapshot
    ) {
        let checkpoint = formatCheckpoint(name: name, time: time, input: input, output: output, audit: nil)
        print(checkpoint)
        appendToLogFile(checkpoint)
    }

    static func printCheckpoint(
        name: String,
        time: Date,
        input: CoachScenarioInputSnapshot,
        output: CoachScenarioOutputSnapshot,
        audit: CoachDecisionAudit
    ) {
        let checkpoint = formatCheckpoint(name: name, time: time, input: input, output: output, audit: audit)
        print(checkpoint)
        appendToLogFile(checkpoint)
    }

    static func formatCheckpoint(
        name: String,
        time: Date,
        input: CoachScenarioInputSnapshot,
        output: CoachScenarioOutputSnapshot
    ) -> String {
        formatCheckpoint(name: name, time: time, input: input, output: output, audit: nil)
    }

    static func formatCheckpoint(
        name: String,
        time: Date,
        input: CoachScenarioInputSnapshot,
        output: CoachScenarioOutputSnapshot,
        audit: CoachDecisionAudit?
    ) -> String {
        """

        === \(name) ===

        INPUT:
        Time: \(input.currentTime)
        Sleep: \(input.sleepInput)
        Meals: \(list(input.mealsInput))
        Deleted meals/items: \(list(input.deletedItems))
        Drinks: \(list(input.drinksInput))
        Activities:
        \(bullets(input.rawStoredRecords))
        Planned activities: \(list(input.plannedActivities))
        Active activities: \(list(input.activeActivities))
        Completed activities: \(list(input.completedActivities))
        Cancelled activities: \(list(input.cancelledActivities))
        Partial activities: \(list(input.partialActivities))
        Sauna: \(input.saunaState)
        Recovery inputs: \(input.recoveryInputs)
        Hydration inputs: \(input.hydrationInputs)

        OUTPUT:
        Today cards:
        \(bullets(output.todayCards))
        Today headline: \(output.todayHeadline)

        Coach:
        Headline: \(output.coachHeadline)
        Next action: \(output.coachNextAction)
        Explanation: \(output.coachExplanation)
        Readiness: \(output.readinessScore)
        Readiness breakdown: \(output.readinessBreakdown)
        Recovery state: \(output.recoveryState)
        Primary limiter: \(output.primaryLimiter)
        Confidence / missing data: \(output.confidenceAndMissingDataState)
        Hydration prompt: \(output.hydrationPrompt)
        Nutrition prompt: \(output.nutritionPrompt)
        Activity recommendation: \(output.activityRecommendation)
        Tomorrow protection: \(output.tomorrowProtection)

        Planner after:
        \(bullets(output.plannerReservations))

        Decision trace:
        \(output.decisionTrace)

        Recommendation trace:
        \(output.recommendationTrace)

        Planner trace:
        \(output.plannerTrace)
        \(auditSection(audit))
        """
    }

    private static func list(_ values: [String]) -> String {
        values.isEmpty ? "none" : values.joined(separator: ", ")
    }

    private static func bullets(_ values: [String]) -> String {
        guard !values.isEmpty else { return "- none" }
        return values.map { "- \($0)" }.joined(separator: "\n")
    }

    private static func auditSection(_ audit: CoachDecisionAudit?) -> String {
        guard let audit else { return "" }
        return """


        COACH DECISION AUDIT:

        RAW INPUTS:
        \(bullets(audit.rawInputs))

        NORMALIZED VALUES:
        \(bullets(audit.normalizedValues))

        SCORING BREAKDOWN:
        \(bullets(audit.scoringBreakdown))

        FINAL DECISION:
        \(bullets(audit.finalDecision))
        """
    }

    private static func appendToLogFile(_ text: String) {
        let data = (text + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }
}
