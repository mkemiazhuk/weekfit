import Foundation

/// Canonical analytics reasons for `morning_proposal_unavailable`.
/// Maps gate/domain strings without inventing product states the engine cannot express.
enum MorningProposalUnavailableAnalyticsReason: String, Sendable, Equatable, CaseIterable {
    case outsideMorningWindow = "outside_morning_window"
    case timeout = "timeout"
    case missingInputs = "missing_inputs"
    case dayExpired = "day_expired"
    case dayStarted = "day_started"
    /// Generic product unavailability — includes former health-permission gate without naming it.
    case other = "other"

    /// Maps a gate / store reason code to a stable analytics value.
    /// Health permission state is intentionally collapsed to `other` (no health signals in Firebase).
    static func fromDomainReason(_ reason: String) -> MorningProposalUnavailableAnalyticsReason {
        switch reason {
        case "health_access_denied":
            return .other
        case "outside_window", "outside_morning_window":
            return .outsideMorningWindow
        case "timeout":
            return .timeout
        case "missing_inputs":
            return .missingInputs
        case "day_expired", "expired":
            return .dayExpired
        case "day_started":
            return .dayStarted
        default:
            return .other
        }
    }
}
