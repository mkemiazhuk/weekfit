import Foundation

/// Central configuration for the App Store In-App Event “7-Day Recovery Challenge”.
///
/// Production stays disabled until real event timestamps are set and
/// `isProductionEnabled` is flipped to `true`.
enum RecoveryChallengeConfig {
    static let eventID = "recovery7.v1"
    static let dayCount = 7

    /// Flip to `true` only after `eventStart` / `eventEnd` are real production instants.
    static let isProductionEnabled = false

    /// Inclusive event window start (UTC instant). Keep `nil` until configured.
    static let eventStart: Date? = nil

    /// Exclusive event window end (UTC instant). Keep `nil` until configured.
    static let eventEnd: Date? = nil

    static let debugPreviewLaunchArgument = "-recovery-challenge-preview"
    static let debugOpenLaunchArgument = "-open-recovery-challenge"

    /// Feature is available when production is configured, or DEBUG preview is active.
    static var isFeatureAvailable: Bool {
        #if DEBUG
        if isDebugPreviewActive { return true }
        #endif
        return isProductionEnabled && eventStart != nil && eventEnd != nil
    }

    #if DEBUG
    static var isDebugPreviewActive: Bool {
        launchArgumentsContain(debugPreviewLaunchArgument)
            || launchArgumentsContain(debugOpenLaunchArgument)
            || UserDefaults.standard.bool(forKey: debugPreviewDefaultsKey)
    }

    static let debugPreviewDefaultsKey = "weekfit.debug.recoveryChallenge.preview"

    static func launchArgumentsContain(_ argument: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == argument
        }
    }

    /// Call once per cold launch while developing the challenge.
    /// - Persists the preview flag so the feature stays on even if scheme args are missing later.
    /// - Clears the one-shot intro flag when not enrolled, so the Today teaser can appear again.
    @discardableResult
    static func prepareDebugPreviewSessionIfNeeded() -> Bool {
        let launchPreview = launchArgumentsContain(debugPreviewLaunchArgument)
            || launchArgumentsContain(debugOpenLaunchArgument)
        if launchPreview {
            UserDefaults.standard.set(true, forKey: debugPreviewDefaultsKey)
        }
        guard isDebugPreviewActive else { return false }

        // Only reset intro once per process — not on every Today refresh.
        if !didPreparePreviewSessionThisProcess {
            didPreparePreviewSessionThisProcess = true
            if RecoveryChallengeStore.load() == nil {
                RecoveryChallengeStore.clearIntroShown()
                return true
            }
        }
        return false
    }

    private static var didPreparePreviewSessionThisProcess = false
    #endif

    /// Resolved event window used by enrollment / surface logic.
    static func eventWindow(now: Date = Date()) -> (start: Date, end: Date)? {
        #if DEBUG
        if isDebugPreviewActive {
            // Wide synthetic window so enrollment + 7 days always fit while developing.
            let start = now.addingTimeInterval(-2 * 24 * 60 * 60)
            let end = now.addingTimeInterval(40 * 24 * 60 * 60)
            return (start, end)
        }
        #endif
        guard isProductionEnabled, let start = eventStart, let end = eventEnd, start < end else {
            return nil
        }
        return (start, end)
    }
}

/// Stable task identifiers (1…7). Copy lives in Localizable.xcstrings.
enum RecoveryChallengeTaskID: Int, Codable, CaseIterable, Sendable {
    case windDownTonight = 1
    case gentleMovement = 2
    case comfortableWalk = 3
    case quietUnwind = 4
    case feelBasedActivity = 5
    case windDownRoutine = 6
    case reflectAndChoose = 7

    var requiresTimeInput: Bool {
        self == .windDownTonight
    }

    var requiresHabitChoice: Bool {
        self == .reflectAndChoose
    }

    var localizationTaskKey: String {
        "challenge.recovery7.task.\(rawValue).title"
    }

    var localizationDetailKey: String {
        "challenge.recovery7.task.\(rawValue).detail"
    }
}

/// Habits offered on day 7 (and shown in the summary when chosen).
enum RecoveryChallengeHabitID: String, Codable, CaseIterable, Sendable {
    case windDownTime
    case gentleMovement
    case comfortableWalk
    case quietUnwind
    case feelBasedActivity
    case windDownRoutine

    var localizationKey: String {
        "challenge.recovery7.habit.\(rawValue)"
    }
}
