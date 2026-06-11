import Foundation
internal import Combine

final class AppSessionState: ObservableObject {

    @Published var returnToTodayTrigger = UUID()
    @Published var healthRefreshTrigger = UUID()
    @Published var coachRefreshTrigger = UUID()
    @Published var localDataResetTrigger = UUID()

    private var pendingHealthRefreshSources: [String] = []
    private var pendingCoachRefreshSources: [String] = []
    private var isHealthRefreshScheduled = false
    private var isCoachRefreshScheduled = false

    func triggerReturnToToday() {
        returnToTodayTrigger = UUID()
    }

    func triggerLocalDataResetCompleted() {
        localDataResetTrigger = UUID()
    }

    func triggerHealthRefresh(source: String = "unspecified") {
        CoachStateStabilizer.markSyncEvent(source: source)
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.triggerHealthRefresh(source: source)
            }
            return
        }

        pendingHealthRefreshSources.append(source)
        guard !isHealthRefreshScheduled else { return }

        isHealthRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushHealthRefresh()
        }
    }

    func triggerCoachRefresh(source: String = "unspecified") {
        CoachStateStabilizer.markSyncEvent(source: source)
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.triggerCoachRefresh(source: source)
            }
            return
        }

        pendingCoachRefreshSources.append(source)
        guard !isCoachRefreshScheduled else { return }

        isCoachRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushCoachRefresh()
        }
    }

    private func flushHealthRefresh() {
        let sources = pendingHealthRefreshSources
        pendingHealthRefreshSources.removeAll()
        isHealthRefreshScheduled = false

        let oldValue = healthRefreshTrigger
        let newValue = UUID()
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshTrigger]",
            "AppSession.healthRefreshTrigger sources=\(summarizeRefreshSources(sources)) \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue))"
        )
        #endif
        healthRefreshTrigger = newValue
    }

    private func flushCoachRefresh() {
        let sources = pendingCoachRefreshSources
        pendingCoachRefreshSources.removeAll()
        isCoachRefreshScheduled = false

        let oldValue = coachRefreshTrigger
        let newValue = UUID()
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshTrigger]",
            "AppSession.coachRefreshTrigger sources=\(summarizeRefreshSources(sources)) \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue))"
        )
        #endif
        coachRefreshTrigger = newValue
    }

    private func summarizeRefreshSources(_ sources: [String]) -> String {
        guard !sources.isEmpty else { return "unspecified" }

        let uniqueSources = Array(Set(sources)).sorted()
        let summary = uniqueSources.prefix(4).joined(separator: ",")
        let overflow = uniqueSources.count > 4 ? ",+\(uniqueSources.count - 4)" : ""
        return "[\(summary)\(overflow)]"
    }
}
