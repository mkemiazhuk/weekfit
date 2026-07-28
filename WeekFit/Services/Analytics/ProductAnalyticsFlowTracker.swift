import Foundation

/// Tracks in-flight logging funnels so cancel emits at most once and never after a terminal.
///
/// Guarantees:
/// - `started` may open a flow
/// - exactly one terminal among completed / failed / cancelled when dismiss is reliable
/// - SwiftUI re-renders alone do not open or close a flow
final class ProductAnalyticsFlowTracker: @unchecked Sendable {
    static let shared = ProductAnalyticsFlowTracker()

    private let lock = NSLock()
    private var food: OpenFood?
    private var hydration: OpenHydration?
    private var activityLogging: OpenActivity?

    private struct OpenFood {
        let method: FoodLoggingMethod
        let source: AnalyticsSource
        var hasTerminal: Bool
    }

    private struct OpenHydration {
        let method: HydrationLoggingMethod
        let source: AnalyticsSource
        var hasTerminal: Bool
    }

    private struct OpenActivity {
        let source: AnalyticsSource
        var hasTerminal: Bool
    }

    func noteFoodStarted(method: FoodLoggingMethod, source: AnalyticsSource) {
        lock.lock()
        food = OpenFood(method: method, source: source, hasTerminal: false)
        lock.unlock()
    }

    func noteFoodTerminal() {
        lock.lock()
        food?.hasTerminal = true
        lock.unlock()
    }

    /// Emits `food_logging_cancelled` once when a started flow has no terminal yet.
    @discardableResult
    func cancelFoodIfNeeded(analytics: AnalyticsTracking) -> Bool {
        lock.lock()
        guard var open = food, !open.hasTerminal else {
            lock.unlock()
            return false
        }
        open.hasTerminal = true
        food = open
        let method = open.method
        let source = open.source
        lock.unlock()

        analytics.track(
            .foodLoggingCancelled,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
        return true
    }

    func noteHydrationStarted(method: HydrationLoggingMethod, source: AnalyticsSource) {
        lock.lock()
        hydration = OpenHydration(method: method, source: source, hasTerminal: false)
        lock.unlock()
    }

    func noteHydrationTerminal() {
        lock.lock()
        hydration?.hasTerminal = true
        lock.unlock()
    }

    @discardableResult
    func cancelHydrationIfNeeded(analytics: AnalyticsTracking) -> Bool {
        lock.lock()
        guard var open = hydration, !open.hasTerminal else {
            lock.unlock()
            return false
        }
        open.hasTerminal = true
        hydration = open
        let method = open.method
        let source = open.source
        lock.unlock()

        analytics.track(
            .hydrationLoggingCancelled,
            parameters: [
                AnalyticsParameterKey.method: method.rawValue,
                AnalyticsParameterKey.source: source.rawValue
            ]
        )
        return true
    }

    func noteActivityLoggingStarted(source: AnalyticsSource) {
        lock.lock()
        activityLogging = OpenActivity(source: source, hasTerminal: false)
        lock.unlock()
    }

    func noteActivityLoggingTerminal() {
        lock.lock()
        activityLogging?.hasTerminal = true
        lock.unlock()
    }

    /// Emits `activity_cancelled` when the Start Activity sheet is dismissed before start/complete/fail.
    @discardableResult
    func cancelActivityLoggingIfNeeded(analytics: AnalyticsTracking) -> Bool {
        lock.lock()
        guard var open = activityLogging, !open.hasTerminal else {
            lock.unlock()
            return false
        }
        open.hasTerminal = true
        activityLogging = open
        let source = open.source
        lock.unlock()

        analytics.track(
            .activityCancelled,
            parameters: [AnalyticsParameterKey.source: source.rawValue]
        )
        return true
    }

    func resetForTests() {
        lock.lock()
        food = nil
        hydration = nil
        activityLogging = nil
        lock.unlock()
    }
}
