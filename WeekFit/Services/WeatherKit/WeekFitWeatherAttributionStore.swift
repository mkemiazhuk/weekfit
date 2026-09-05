import Foundation
import WeatherKit
internal import Combine

/// Loads and caches Apple WeatherKit `WeatherAttribution` for UI attribution.
///
/// Required wherever WeatherKit-derived weather is shown to the user.
@MainActor
final class WeekFitWeatherAttributionStore: ObservableObject {
    static let shared = WeekFitWeatherAttributionStore()

    @Published private(set) var attribution: WeatherAttribution?
    @Published private(set) var loadFailed = false

    private var loadTask: Task<Void, Never>?

    private init() {}

    /// Idempotent — safe to call from every weather-facing screen.
    func ensureLoaded() {
        if attribution != nil || loadFailed { return }
        if loadTask != nil { return }

        loadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.loadTask = nil }
            do {
                let value = try await WeatherService.shared.attribution
                guard !Task.isCancelled else { return }
                self.attribution = value
                self.loadFailed = false
            } catch {
                guard !Task.isCancelled else { return }
                self.loadFailed = true
            }
        }
    }

    func resetForTests() {
        loadTask?.cancel()
        loadTask = nil
        attribution = nil
        loadFailed = false
    }
}
