import Foundation
internal import Combine

enum MissingSleepNoticeSurface: Equatable {
    case today
    case coach
}

struct MissingSleepMorningNoticeInput: Equatable {
    var now: Date
    var calendar: Calendar = .current
    var isHealthAccessGranted: Bool
    var hasSettledMetrics: Bool
    var isLoadingMetrics: Bool
    var sleepReadConfirmed: Bool
    var hasSleepRecords: Bool
    var hasShownToday: Bool
    var isHeldOnScreen: Bool
}

enum MissingSleepMorningNoticePhase: Equatable {
    case hidden
    case show
}

enum MissingSleepMorningNoticePolicy {

    /// Local hour at which the morning notice stops, even if the app stays open.
    static let cutoffHour = 11

    static func phase(_ input: MissingSleepMorningNoticeInput) -> MissingSleepMorningNoticePhase {
        if input.hasSleepRecords { return .hidden }
        let hour = input.calendar.component(.hour, from: input.now)
        if hour >= cutoffHour { return .hidden }
        if input.isHeldOnScreen { return .show }
        guard input.isHealthAccessGranted,
              input.hasSettledMetrics,
              !input.isLoadingMetrics,
              input.sleepReadConfirmed,
              !input.hasShownToday
        else { return .hidden }
        return .show
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func secondsUntilCutoff(now: Date, calendar: Calendar = .current) -> TimeInterval {
        var parts = calendar.dateComponents([.year, .month, .day], from: now)
        parts.hour = cutoffHour
        parts.minute = 0
        parts.second = 0
        guard let cutoff = calendar.date(from: parts) else { return 0 }
        return max(0, cutoff.timeIntervalSince(now))
    }
}

struct MissingSleepMorningNoticeStore {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasShown(owner: String, dayKey: String) -> Bool {
        defaults.bool(forKey: storageKey(owner: owner, dayKey: dayKey))
    }

    func markShown(owner: String, dayKey: String) {
        defaults.set(true, forKey: storageKey(owner: owner, dayKey: dayKey))
    }

    private func storageKey(owner: String, dayKey: String) -> String {
        "weekfit.missingSleepMorningNotice.shown.\(owner).\(dayKey)"
    }
}

struct MissingSleepMorningNoticeCoordinator {
    var holder: MissingSleepNoticeSurface?
    var store: MissingSleepMorningNoticeStore

    func phase(
        for surface: MissingSleepNoticeSurface,
        input: MissingSleepMorningNoticeInput
    ) -> MissingSleepMorningNoticePhase {
        var resolved = input
        resolved.isHeldOnScreen = holder == surface
        return MissingSleepMorningNoticePolicy.phase(resolved)
    }

    mutating func noteAppeared(
        surface: MissingSleepNoticeSurface,
        owner: String,
        dayKey: String
    ) {
        guard holder == nil || holder == surface else { return }
        holder = surface
        store.markShown(owner: owner, dayKey: dayKey)
    }

    mutating func end(_ surface: MissingSleepNoticeSurface) {
        guard holder == surface else { return }
        holder = nil
    }
}

@MainActor
final class MissingSleepMorningNoticeSession: ObservableObject {
    static let shared = MissingSleepMorningNoticeSession()

    @Published private(set) var holder: MissingSleepNoticeSurface?
    private let store = MissingSleepMorningNoticeStore()
    private var cutoffTask: Task<Void, Never>?

    func isHeld(by surface: MissingSleepNoticeSurface) -> Bool {
        holder == surface
    }

    func hasShown(owner: String, dayKey: String) -> Bool {
        store.hasShown(owner: owner, dayKey: dayKey)
    }

    func noteAppeared(surface: MissingSleepNoticeSurface, owner: String, dayKey: String) {
        guard holder == nil || holder == surface else { return }
        holder = surface
        store.markShown(owner: owner, dayKey: dayKey)
        armCutoff()
    }

    func end(_ surface: MissingSleepNoticeSurface) {
        guard holder == surface else { return }
        holder = nil
        cutoffTask?.cancel()
        cutoffTask = nil
    }

    /// Keeps the notice up to the local cutoff even if the screen does not refresh.
    private func armCutoff() {
        cutoffTask?.cancel()
        let delay = MissingSleepMorningNoticePolicy.secondsUntilCutoff(now: Date())
        guard delay > 0 else {
            holder = nil
            cutoffTask = nil
            return
        }
        cutoffTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64((delay * 1_000_000_000).rounded())
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.holder = nil
            self.cutoffTask = nil
        }
    }
}
