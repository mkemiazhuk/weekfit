import Foundation
@testable import WeekFit

/// In-memory analytics sink for unit tests. Does not touch Firebase.
final class RecordingAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var recordedEvents: [(event: AnalyticsEvent, parameters: [String: String])] = []
    private(set) var recordedScreens: [(screen: AnalyticsScreen, parameters: [String: String])] = []

    func track(_ event: AnalyticsEvent, parameters: [String: String]) {
        lock.lock()
        recordedEvents.append((event, parameters))
        lock.unlock()
    }

    func trackScreen(_ screen: AnalyticsScreen, parameters: [String: String]) {
        lock.lock()
        recordedScreens.append((screen, parameters))
        lock.unlock()
    }

    func reset() {
        lock.lock()
        recordedEvents.removeAll()
        recordedScreens.removeAll()
        lock.unlock()
    }

    func events(named event: AnalyticsEvent) -> [(event: AnalyticsEvent, parameters: [String: String])] {
        lock.lock()
        defer { lock.unlock() }
        return recordedEvents.filter { $0.event == event }
    }

    func parameterValues(for event: AnalyticsEvent, key: String) -> [String] {
        events(named: event).compactMap { $0.parameters[key] }
    }
}
