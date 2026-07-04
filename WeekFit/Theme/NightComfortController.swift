import CoreLocation
import Foundation
internal import Combine

@MainActor
final class NightComfortController: ObservableObject {

    @Published private(set) var blendFactor: CGFloat = 0
    @Published private(set) var preference: NightComfortPreference

    var resolvedPalette: WeekFitSemanticPalette {
        WeekFitSemanticPalette.interpolated(blend: blendFactor)
    }

    private nonisolated(unsafe) var refreshTimer: Timer?
    private var solarCoordinate: CLLocationCoordinate2D?

    init(preference: NightComfortPreference = .stored) {
        self.preference = preference
        refreshBlend(reason: RefreshReason.initLoad)
        scheduleNextRefresh()
    }

    func setPreference(_ preference: NightComfortPreference) {
        guard self.preference != preference else { return }
        self.preference = preference
        NightComfortPreference.store(preference)
        refreshBlend(reason: RefreshReason.preferenceChange)
        scheduleNextRefresh()
    }

    func updateSolarCoordinate(_ coordinate: CLLocationCoordinate2D?) {
        guard !coordinatesEqual(solarCoordinate, coordinate) else { return }
        solarCoordinate = coordinate
        refreshBlend(reason: RefreshReason.solarCoordinate)
        scheduleNextRefresh()
    }

    func handleSceneBecameActive() {
        preference = NightComfortPreference.stored
        refreshBlend(reason: RefreshReason.sceneActive)
        scheduleNextRefresh()
    }

    func refreshBlend(now: Date = Date(), reason: String = RefreshReason.timer) {
        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        let solarTimes = solarCoordinate.flatMap {
            NightComfortSolarTimeProvider.solarTimes(
                on: now,
                coordinate: $0,
                timeZone: timeZone,
                calendar: calendar
            )
        }

        let input = NightComfortWindowPolicy.Input(
            now: now,
            sunset: solarTimes?.sunset,
            sunrise: solarTimes?.sunrise,
            calendar: calendar,
            preference: preference
        )

        let newBlend = NightComfortWindowPolicy.blendFactor(input)

        #if DEBUG
        let shouldLogState =
            newBlend != blendFactor ||
            reason == RefreshReason.initLoad ||
            reason == RefreshReason.solarCoordinate

        if shouldLogState {
            NightComfortDebug.logState(
                preference: preference,
                blend: newBlend,
                reason: reason,
                solarAvailable: solarCoordinate != nil,
                solarTimes: solarTimes
            )
        }
        #endif

        blendFactor = newBlend
        WeekFitPaletteStore.update(blend: newBlend)
    }

    private enum RefreshReason {
        static let initLoad = "init"
        static let preferenceChange = "preferenceChange"
        static let sceneActive = "sceneActive"
        static let solarCoordinate = "solarCoordinate"
        static let timer = "timer"
    }

    private func scheduleNextRefresh() {
        refreshTimer?.invalidate()

        let now = Date()
        let calendar = Calendar.current
        let solarTimes = solarCoordinate.flatMap {
            NightComfortSolarTimeProvider.solarTimes(
                on: now,
                coordinate: $0,
                timeZone: calendar.timeZone,
                calendar: calendar
            )
        }

        let input = NightComfortWindowPolicy.Input(
            now: now,
            sunset: solarTimes?.sunset,
            sunrise: solarTimes?.sunrise,
            calendar: calendar,
            preference: preference
        )

        if preference != .automatic {
            return
        }

        if let nextTransition = NightComfortWindowPolicy.nextTransition(after: now, input: input) {
            let interval = max(1, nextTransition.timeIntervalSince(now))
            refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshBlend(reason: RefreshReason.timer)
                    self?.scheduleNextRefresh()
                }
            }
            return
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBlend(reason: RefreshReason.timer)
            }
        }
    }

    private func coordinatesEqual(
        _ lhs: CLLocationCoordinate2D?,
        _ rhs: CLLocationCoordinate2D?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return abs(left.latitude - right.latitude) < 0.0001 &&
                abs(left.longitude - right.longitude) < 0.0001
        default:
            return false
        }
    }
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {
        refreshTimer?.invalidate()
    }
}
