import Foundation

/// Canonical analytics reasons for `morning_proposal_unavailable`.
/// Maps gate/domain strings without inventing product states the engine cannot express.
/// Never encodes HealthKit quantities — only coarse availability categories.
enum MorningProposalUnavailableAnalyticsReason: String, Sendable, Equatable, CaseIterable {
    case outsideMorningWindow = "outside_morning_window"
    /// Health refresh timed out before usable morning inputs settled.
    case timeout = "timeout"
    /// Recovery / sleep / plan inputs required for a proposal were not present.
    case missingData = "missing_data"
    /// Health (or equivalent) permission not granted — categorical only.
    case permissionsDenied = "permissions_denied"
    /// Day/plan inputs were still loading when the surface closed as unavailable.
    case loadIncomplete = "load_incomplete"
    /// Engine produced an unavailable / failed generation outcome.
    case generationFailed = "generation_failed"
    case dayExpired = "day_expired"
    case dayStarted = "day_started"
    /// Generic product unavailability — catch-all for unmapped domain codes.
    case other = "other"

    /// Gate vs engine — never conflates in-flight loading with a terminal failure.
    enum Stage: String, Sendable {
        case gate
        case engine
    }

    /// Expected calendar/product state vs blocked inputs vs failed generation.
    enum OutcomeClass: String, Sendable {
        /// Normal product state (after noon, day already started) — not an error.
        case expected
        /// Inputs missing / denied / timed out — not a crash, but proposal blocked.
        case insufficientInput = "insufficient_input"
        /// Engine/generation terminal failure.
        case failed
    }

    /// Expected calendar outcomes are persisted for UI but **not** emitted as
    /// `morning_proposal_unavailable` — they flooded Firebase (afternoon opens).
    var shouldEmitUnavailableEvent: Bool {
        switch self {
        case .outsideMorningWindow, .dayStarted, .dayExpired:
            return false
        case .timeout, .missingData, .permissionsDenied, .loadIncomplete,
             .generationFailed, .other:
            return true
        }
    }

    var outcomeClass: OutcomeClass {
        switch self {
        case .outsideMorningWindow, .dayStarted, .dayExpired:
            return .expected
        case .timeout, .missingData, .permissionsDenied, .loadIncomplete:
            return .insufficientInput
        case .generationFailed, .other:
            return .failed
        }
    }

    /// Maps a gate / store / engine reason code to a stable analytics value.
    static func fromDomainReason(_ reason: String) -> MorningProposalUnavailableAnalyticsReason {
        switch reason {
        case "health_access_denied", "permissions_denied":
            return .permissionsDenied
        case "outside_window", "outside_morning_window":
            return .outsideMorningWindow
        case "timeout":
            return .timeout
        case "missing_inputs", "missing_data":
            return .missingData
        case "load_incomplete", "gathering_data":
            // Gathering itself must not emit unavailable; this maps only if a
            // terminal path incorrectly surfaces the token.
            return .loadIncomplete
        case "generation_failed", "closed", "generation_mode_closed", "failed":
            return .generationFailed
        case "day_expired", "expired":
            return .dayExpired
        case "day_started":
            return .dayStarted
        default:
            return .other
        }
    }
}
