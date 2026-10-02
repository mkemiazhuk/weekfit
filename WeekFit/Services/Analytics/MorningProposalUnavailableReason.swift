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
