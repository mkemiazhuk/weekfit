import Foundation
internal import Combine

@MainActor
final class AppSessionState: ObservableObject {

    @Published private(set) var returnToTodayEvent = AppRefreshEvent(kind: .returnToToday)
    @Published private(set) var healthRefreshEvent = AppRefreshEvent(kind: .healthRefresh)
    @Published private(set) var coachRefreshEvent = AppRefreshEvent(kind: .coachRefresh)
    @Published private(set) var localDataResetEvent = AppRefreshEvent(kind: .localDataResetCompleted)

    private var pendingHealthRefreshSources: [String] = []
    private var pendingCoachRefreshSources: [String] = []
    private var isHealthRefreshScheduled = false
    private var isCoachRefreshScheduled = false

    var returnToTodayTrigger: UUID { returnToTodayEvent.token }
    var healthRefreshTrigger: UUID { healthRefreshEvent.token }
    var coachRefreshTrigger: UUID { coachRefreshEvent.token }
    var localDataResetTrigger: UUID { localDataResetEvent.token }

    func triggerReturnToToday() {
        returnToTodayEvent = AppRefreshEvent(kind: .returnToToday)
    }

    func triggerLocalDataResetCompleted() {
        localDataResetEvent = AppRefreshEvent(kind: .localDataResetCompleted)
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

        let oldValue = healthRefreshEvent.token
        let newEvent = AppRefreshEvent(kind: .healthRefresh, sources: sources)
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshTrigger]",
            "AppSession.healthRefreshEvent sources=\(summarizeRefreshSources(sources)) \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newEvent.token))"
        )
        #endif
        healthRefreshEvent = newEvent
    }

    private func flushCoachRefresh() {
        let sources = pendingCoachRefreshSources
        pendingCoachRefreshSources.removeAll()
        isCoachRefreshScheduled = false

        let oldValue = coachRefreshEvent.token
        let newEvent = AppRefreshEvent(kind: .coachRefresh, sources: sources)
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshTrigger]",
            "AppSession.coachRefreshEvent sources=\(summarizeRefreshSources(sources)) \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newEvent.token))"
        )
        #endif
        coachRefreshEvent = newEvent
    }

    private func summarizeRefreshSources(_ sources: [String]) -> String {
        guard !sources.isEmpty else { return "unspecified" }

        let uniqueSources = Array(Set(sources)).sorted()
        let summary = uniqueSources.prefix(4).joined(separator: ",")
        let overflow = uniqueSources.count > 4 ? ",+\(uniqueSources.count - 4)" : ""
        return "[\(summary)\(overflow)]"
    }
}
