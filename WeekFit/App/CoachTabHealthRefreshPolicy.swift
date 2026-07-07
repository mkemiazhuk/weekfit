import Foundation

/// Coach tab HealthKit reload policy.
///
/// Optimization must be event-driven, not "never refresh".
/// We skip duplicate refreshes caused by tab activation only.
/// Real data events must always win over throttling.
enum CoachTabHealthRefreshPolicy {

    /// Minimum age of the last successful HealthKit sync before a coach-tab visit
    /// may reload on tab activation alone (no pending data event).
    static let minRefreshInterval: TimeInterval = 120

    enum Trigger: Equatable {
        /// User selected the Coach tab; not itself a data-change signal.
        case coachTabActivation
        /// `AppSessionState.triggerHealthRefresh` fired (Watch sync, foreground, manual, etc.).
        case healthRefreshEvent(sources: [String])
        /// Explicit manual / force path that must bypass throttle.
        case manualForce(source: String)
    }

    struct Input: Equatable {
        var trigger: Trigger
        var healthRefreshToken: UUID
        var acknowledgedHealthRefreshToken: UUID?
        var lastHealthKitSyncTime: Date?
        var isHealthAccessRequested: Bool
        var now: Date
    }

    struct Decision: Equatable {
        let shouldReloadHealth: Bool
        let reason: String
        let bypassesThrottle: Bool
    }

    static func evaluate(_ input: Input) -> Decision {
        guard input.isHealthAccessRequested else {
            return Decision(
                shouldReloadHealth: false,
                reason: "healthAccessNotRequested",
                bypassesThrottle: false
            )
        }

        switch input.trigger {
        case .manualForce(let source):
            return Decision(
                shouldReloadHealth: true,
                reason: "manualForce:\(source)",
                bypassesThrottle: true
            )

        case .healthRefreshEvent(let sources):
            let label = summarizeSources(sources)
            return Decision(
                shouldReloadHealth: true,
                reason: "healthRefreshEvent:\(label)",
                bypassesThrottle: true
            )

        case .coachTabActivation:
            if input.healthRefreshToken != input.acknowledgedHealthRefreshToken {
                return Decision(
                    shouldReloadHealth: true,
                    reason: "pendingHealthRefreshToken",
                    bypassesThrottle: true
                )
            }

            guard let lastSync = input.lastHealthKitSyncTime else {
                return Decision(
                    shouldReloadHealth: true,
                    reason: "noPriorHealthKitSync",
                    bypassesThrottle: false
                )
            }

            let age = input.now.timeIntervalSince(lastSync)
            if age >= minRefreshInterval {
                return Decision(
                    shouldReloadHealth: true,
                    reason: "staleHealthKitSync ageSec=\(Int(age))",
                    bypassesThrottle: false
                )
            }

            return Decision(
                shouldReloadHealth: false,
                reason: "tabActivationNoise freshSync ageSec=\(Int(age))",
                bypassesThrottle: false
            )
        }
    }

    /// Sources that represent real external data changes (Watch, HealthKit observer, etc.).
    static func isDataEventSource(_ source: String) -> Bool {
        let normalized = source.lowercased()
        let markers = [
            "completedworkouts",
            "watch",
            "healthkit",
            "hkobserver",
            "workout",
            "appforeground",
            "manual",
            "forcerefresh",
            "healthdataloaded",
            "localdatareset",
            "bodygoalchanged"
        ]
        return markers.contains { normalized.contains($0) }
    }

    static func summarizeSources(_ sources: [String]) -> String {
        guard !sources.isEmpty else { return "unspecified" }
        return sources.prefix(3).joined(separator: ",")
    }
}

#if DEBUG
enum HealthRefreshGuardLog {
    static func log(
        event: String,
        decision: CoachTabHealthRefreshPolicy.Decision,
        sources: [String] = []
    ) {
        guard CoachDebugSettings.healthRefreshGuardLoggingEnabled else { return }
        let sourceNote = sources.isEmpty ? "" : " sources=[\(CoachTabHealthRefreshPolicy.summarizeSources(sources))]"
        print(
            "[HealthRefreshGuard] event=\(event) reload=\(decision.shouldReloadHealth) bypassThrottle=\(decision.bypassesThrottle) reason=\(decision.reason)\(sourceNote)"
        )
    }

    static func logStaleCoachRefreshDropped(generation: Int, currentGeneration: Int, source: String) {
        guard CoachDebugSettings.healthRefreshGuardLoggingEnabled else { return }
        print(
            "[HealthRefreshGuard] staleCoachRefreshDropped source=\(source) taskGen=\(generation) currentGen=\(currentGeneration)"
        )
    }
}
#endif
