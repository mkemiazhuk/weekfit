import Foundation
internal import Combine

enum AppReviewDemoStore {
    static let enabledKey = "weekfit.appReviewDemoEnabled"
    static let scenarioKey = "weekfit.appReviewDemoScenario"
    static let sessionActiveKey = "weekfit.appReviewSessionActive"
    static let seedVersionKey = "weekfit.appReviewDemoSeedVersion"
    static let lastSeedDayKey = "weekfit.appReviewDemoLastSeedDay"
    /// Bump when seeded demo activities change so existing demo stores reseed.
    static let currentSeedVersion = 3
    static let sourceIdentifier = "appReviewDemo"
}

@MainActor
final class AppReviewDemoSettings: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    static let shared = AppReviewDemoSettings()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var scenario: AppReviewDemoScenario

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: AppReviewDemoStore.enabledKey)
        let rawScenario = defaults.string(forKey: AppReviewDemoStore.scenarioKey)
        scenario = AppReviewDemoScenario(rawValue: rawScenario ?? "") ?? .readyToTrain

        if isEnabled, !AppReviewDemoCredentials.hasActiveSession {
            isEnabled = false
            defaults.set(false, forKey: AppReviewDemoStore.enabledKey)
        }
    }

    var isActive: Bool { isEnabled && AppReviewDemoCredentials.hasActiveSession }

    func setEnabled(_ enabled: Bool, scenario: AppReviewDemoScenario? = nil) {
        if let scenario {
            self.scenario = scenario
            defaults.set(scenario.rawValue, forKey: AppReviewDemoStore.scenarioKey)
        }

        guard isEnabled != enabled else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: AppReviewDemoStore.enabledKey)
    }

    func setScenario(_ scenario: AppReviewDemoScenario) {
        guard self.scenario != scenario else { return }
        self.scenario = scenario
        defaults.set(scenario.rawValue, forKey: AppReviewDemoStore.scenarioKey)
    }

    func resetForTests() {
        defaults.removeObject(forKey: AppReviewDemoStore.enabledKey)
        defaults.removeObject(forKey: AppReviewDemoStore.scenarioKey)
        isEnabled = false
        scenario = .readyToTrain
    }
}

enum AppReviewDemoPlannedActivityTagger {
    static func tagIfNeeded(_ activity: PlannedActivity) {
        guard AccountSessionController.shared.mode == .reviewDemo else { return }
        activity.source = AppReviewDemoStore.sourceIdentifier
    }
}
