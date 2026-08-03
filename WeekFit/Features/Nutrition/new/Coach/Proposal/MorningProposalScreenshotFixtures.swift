#if DEBUG
import Foundation

/// Deterministic morning proposal used for screenshots / UI harnesses.
enum MorningProposalScreenshotFixtures {

    static let launchSeedArgument = "-seed-morning-proposal"
    static let launchOpenReviewArgument = "-open-morning-proposal-review"

    static var shouldSeed: Bool {
        ProcessInfo.processInfo.arguments.contains(launchSeedArgument)
            || ProcessInfo.processInfo.arguments.contains(launchOpenReviewArgument)
    }

    static var shouldOpenReview: Bool {
        ProcessInfo.processInfo.arguments.contains(launchOpenReviewArgument)
    }

    static func sampleProposal(now: Date = Date()) -> MorningPlanProposal {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let dayKey = Self.dayKey(for: now, calendar: calendar)

        func at(hour: Int, minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? now
        }

        let shorten = CoachProposedChange(
            id: "shot-shorten",
            kind: .modifyDuration,
            reasonCode: .lowRecoveryLoadProtection,
            payload: .modifyDuration(
                ModifyDurationPayload(
                    activityId: "a-tempo",
                    originalDurationMinutes: 60,
                    proposedDurationMinutes: 40,
                    activityTitle: "Tempo Run"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: at(hour: 17, minute: 30),
            evidenceScenarioKey: "lowRecovery",
            scoreTotal: 92
        )

        let breakfast = CoachProposedChange(
            id: "shot-meal-am",
            kind: .createMealFromLibrary,
            reasonCode: .libraryMealSupport,
            payload: .createMealFromLibrary(
                CreateMealFromLibraryPayload(
                    mealId: "meal-eggs",
                    title: "Eggs & Oats",
                    proposedDate: at(hour: 8, minute: 30),
                    durationMinutes: 15,
                    calories: 420,
                    protein: 28,
                    carbs: 38,
                    fats: 14,
                    fiber: 6,
                    imageName: "plate-dark"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: at(hour: 8, minute: 30),
            evidenceScenarioKey: "lowRecovery",
            scoreTotal: 78
        )

        let dinner = CoachProposedChange(
            id: "shot-meal-pm",
            kind: .createMealFromLibrary,
            reasonCode: .libraryMealSupport,
            payload: .createMealFromLibrary(
                CreateMealFromLibraryPayload(
                    mealId: "meal-bowl",
                    title: "Recovery Bowl",
                    proposedDate: at(hour: 19, minute: 0),
                    durationMinutes: 15,
                    calories: 540,
                    protein: 36,
                    carbs: 48,
                    fats: 18,
                    fiber: 9,
                    imageName: "plate-dark"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: at(hour: 19, minute: 0),
            evidenceScenarioKey: "lowRecovery",
            scoreTotal: 74
        )

        let walk = CoachProposedChange(
            id: "shot-walk",
            kind: .createRecoveryWalk,
            reasonCode: .recoveryWalkSupport,
            payload: .createRecoveryWalk(
                CreateRecoveryWalkPayload(
                    proposedDate: at(hour: 12, minute: 30),
                    durationMinutes: 25,
                    title: "Walk",
                    activityType: "recovery"
                )
            ),
            defaultSelected: true,
            isSelected: true,
            sortTime: at(hour: 12, minute: 30),
            evidenceScenarioKey: "lowRecovery",
            scoreTotal: 81
        )

        let tip = CoachProposedChange(
            id: "shot-tip",
            kind: .guidanceOnly,
            reasonCode: .planAlreadyAppropriate,
            payload: .guidanceOnly(
                GuidanceOnlyPayload(guidanceCode: .hydrateThroughMorning, relatedActivityId: nil)
            ),
            defaultSelected: false,
            isSelected: false,
            sortTime: at(hour: 9, minute: 0),
            evidenceScenarioKey: "lowRecovery"
        )

        return MorningPlanProposal(
            id: "screenshot-proposal",
            dayKey: dayKey,
            generatedAt: now,
            status: .proposalReady,
            fingerprint: ProposalInputFingerprint(
                dayKey: dayKey,
                planSignature: "screenshot-plan",
                tomorrowPlanSignature: "screenshot-tomorrow",
                recoveryBand: .low,
                sleepPresence: .present,
                scenarioKey: "lowRecovery",
                yesterdayHeavy: true,
                observationContextRevision: "screenshot",
                generationMode: MorningProposalGenerationMode.compose.rawValue
            ),
            changes: [breakfast, walk, shorten, dinner, tip],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            strategy: .recover
        )
    }

    static func seedIfNeeded() {
        guard shouldSeed else { return }
        let proposal = sampleProposal()
        MorningProposalStore.upsert(proposal)
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
#endif
