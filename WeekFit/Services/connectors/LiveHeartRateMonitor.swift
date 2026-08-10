import Foundation
import HealthKit
import UIKit
internal import Combine

/// Phone-side live heart-rate reader for in-session coaching.
/// Relies on Watch / chest strap writing HR samples into HealthKit — no Watch app required.
@MainActor
final class LiveHeartRateMonitor: ObservableObject {
    nonisolated deinit {}

    static let shared = LiveHeartRateMonitor()

    @Published private(set) var currentBPM: Int?
    @Published private(set) var currentZone: Int?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var isMonitoring = false

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var pollTask: Task<Void, Never>?
    private var sessionStartedAt: Date?
    private var protectedDataObservers: [NSObjectProtocol] = []

    /// Prefer samples from this window; workout HR can lag a bit behind the Watch UI.
    private let freshnessWindow: TimeInterval = 180
    private let pollIntervalNanoseconds: UInt64 = 3_000_000_000

    private init() {}

    func start(sessionStartedAt: Date = Date()) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Prefer the earlier session start so we don't shrink the lookback window.
        if let existing = self.sessionStartedAt {
            self.sessionStartedAt = min(existing, sessionStartedAt)
        } else {
            self.sessionStartedAt = sessionStartedAt
        }

        guard !isMonitoring else {
            fetchLatest()
            return
        }

        isMonitoring = true
        startProtectedDataObservers()
        startObserver(type: type)
        fetchLatest()
        startPolling()
    }

    func stop() {
        // Idempotent: always tear down queries + background delivery even if already stopped.
        let wasMonitoring = isMonitoring
        isMonitoring = false
        sessionStartedAt = nil

        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
        pollTask?.cancel()
        pollTask = nil
        stopProtectedDataObservers()

        if let type = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            healthStore.disableBackgroundDelivery(for: type) { _, _ in }
        }

        currentBPM = nil
        currentZone = nil
        updatedAt = nil

        // Keep wasMonitoring for readability / future diagnostics.
        _ = wasMonitoring
    }

    // MARK: - Protected data

    /// HealthKit heart-rate samples are file-protected until the device is unlocked.
    private var isHealthDataReadable: Bool {
        UIApplication.shared.isProtectedDataAvailable
    }

    private func startProtectedDataObservers() {
        guard protectedDataObservers.isEmpty else { return }

        let center = NotificationCenter.default
        let unlock = center.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fetchLatest()
            }
        }
        let active = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fetchLatest()
            }
        }
        protectedDataObservers = [unlock, active]
    }

    private func stopProtectedDataObservers() {
        let center = NotificationCenter.default
        for observer in protectedDataObservers {
            center.removeObserver(observer)
        }
        protectedDataObservers = []
    }

    private nonisolated static func isProtectedDataError(_ error: Error?) -> Bool {
        guard let error else { return false }
        let nsError = error as NSError
        // HKError.Code.protectedDataUnavailable is not consistently exposed across SDKs;
        // code 6 is the documented HealthKit protected-data failure.
        if nsError.domain == HKErrorDomain, nsError.code == 6 {
            return true
        }
        return nsError.localizedDescription.localizedCaseInsensitiveContains("protected health data")
            || nsError.localizedDescription.localizedCaseInsensitiveContains("protected data")
    }

    // MARK: - HealthKit

    private func startObserver(type: HKQuantityType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            // Always complete promptly — never wait on MainActor for HealthKit delivery.
            completionHandler()
            guard error == nil else { return }
            Task { @MainActor in
                self?.fetchLatest()
            }
        }

        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.isMonitoring {
                try? await Task.sleep(nanoseconds: self.pollIntervalNanoseconds)
                guard !Task.isCancelled, self.isMonitoring else { return }
                self.fetchLatest()
            }
        }
    }

    private func fetchLatest() {
        guard isMonitoring else { return }
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Skip while the phone is locked — querying would only log
        // "Protected health data is inaccessible" and keep last known BPM.
        guard isHealthDataReadable else { return }

        let now = Date()
        // Wide lookback: planned start can precede Watch samples; also catch mid-session spikes.
        let sessionAnchor = sessionStartedAt ?? now
        let lookbackStart = min(sessionAnchor, now.addingTimeInterval(-30 * 60))
        let predicate = HKQuery.predicateForSamples(
            withStart: lookbackStart,
            end: now,
            options: .strictEndDate
        )

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 30,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { [weak self] _, samples, error in
            if let error {
                // Expected while locked / unlocking — keep last BPM and retry on unlock.
                if Self.isProtectedDataError(error) {
                    return
                }
                #if DEBUG
                print("[LiveHeartRate] query error: \(error.localizedDescription)")
                #endif
                return
            }

            let quantitySamples = (samples as? [HKQuantitySample]) ?? []
            let unit = HKUnit.count().unitDivided(by: .minute())
            let freshness = self?.freshnessWindow ?? 180
            let freshCutoff = now.addingTimeInterval(-freshness)

            let freshSamples = quantitySamples.filter { $0.endDate >= freshCutoff }
            let candidateSamples = freshSamples.isEmpty ? Array(quantitySamples.prefix(3)) : freshSamples

            let bpms: [Int] = candidateSamples.compactMap { sample in
                let value = Int(sample.quantity.doubleValue(for: unit).rounded())
                guard value > 30, value < 250 else { return nil }
                return value
            }

            // Peak in the fresh window — Watch UI often shows a spike before the "current" sample settles.
            guard let bpm = bpms.max() else {
                Task { @MainActor in
                    guard let self else { return }
                    if let updatedAt = self.updatedAt,
                       now.timeIntervalSince(updatedAt) > freshness * 2 {
                        self.currentBPM = nil
                        self.currentZone = nil
                    }
                }
                return
            }

            let zone = HeartRateZones.zone(forBPM: bpm)
            let newestEnd = candidateSamples.map(\.endDate).max() ?? now

            Task { @MainActor in
                guard let self, self.isMonitoring else { return }
                let previousZone = self.currentZone
                let previousBPM = self.currentBPM
                self.currentBPM = bpm
                self.currentZone = zone
                self.updatedAt = newestEnd

                let zoneChanged = previousZone != zone
                let firstSample = previousBPM == nil
                let enteredElevated = HeartRateZones.isElevated(zone)
                    && (previousZone == nil || !HeartRateZones.isElevated(previousZone ?? 0))

                if firstSample || zoneChanged || enteredElevated {
                    NotificationCenter.default.post(
                        name: .weekFitLiveHeartRateZoneDidChange,
                        object: nil,
                        userInfo: ["bpm": bpm, "zone": zone]
                    )
                }
            }
        }

        healthStore.execute(query)
    }
}

extension Notification.Name {
    static let weekFitLiveHeartRateZoneDidChange = Notification.Name("weekFitLiveHeartRateZoneDidChange")
}
