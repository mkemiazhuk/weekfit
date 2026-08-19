import Foundation

/// App-level WeekFit access. There is no separate Pro tier.
enum WeekFitAccessState: Equatable, Sendable {
    /// Entitlements have not finished loading, or StoreKit has never produced
    /// a verified resolution on this install. Fail-open only in this case so
    /// legacy users are not locked out during migration.
    case loading
    /// Original App Store download is before the monetization cutoff.
    case legacy
    /// Active introductory free trial.
    case trial
    /// Active paid subscription, billing retry, or grace period.
    case subscribed
    /// Had a WeekFit subscription that is no longer active.
    case expired
    /// Not legacy and no current subscription.
    case unsubscribed
}

/// Last StoreKit-verified outcome persisted for offline / StoreKit-down fallback.
/// Never authoritative while verification is available.
enum WeekFitVerifiedEntitlement: String, Equatable, Sendable {
    case legacy
    case trial
    case subscribed
    case expired
    case unsubscribed

    var accessState: WeekFitAccessState {
        switch self {
        case .legacy: return .legacy
        case .trial: return .trial
        case .subscribed: return .subscribed
        case .expired: return .expired
        case .unsubscribed: return .unsubscribed
        }
    }

    init?(accessState: WeekFitAccessState) {
        switch accessState {
        case .loading:
            return nil
        case .legacy:
            self = .legacy
        case .trial:
            self = .trial
        case .subscribed:
            self = .subscribed
        case .expired:
            self = .expired
        case .unsubscribed:
            self = .unsubscribed
        }
    }
}

enum WeekFitAppTransactionStatus: Equatable, Sendable {
    case loading
    case verified(originalPurchaseDate: Date, environment: String)
    /// JWS verification failed. Do not trust the embedded date.
    case unverified(environment: String)
    /// StoreKit threw or AppTransaction is unavailable (simulator, offline).
    case unavailable
}

struct WeekFitSubscriptionSnapshot: Equatable, Sendable {
    var productID: String
    var isIntroductoryTrial: Bool
    var expirationDate: Date?
    var isExpired: Bool
    var isRevoked: Bool
    var inGraceOrRetry: Bool
    /// False when the user cancelled auto-renewal but the current period is still active.
    var willAutoRenew: Bool = true
}

/// Injectable test bypass. Production must always use `.none`.
struct WeekFitEntitlementBypass: Equatable, Sendable {
    static let none = WeekFitEntitlementBypass()

    /// Never grants entitlement by itself; use explicit launch-argument overrides in DEBUG UI tests.
    var grantsAccess: Bool { false }
}

enum WeekFitPurchaseOutcome: Equatable, Sendable {
    case success
    case cancelled
    case pending
    case failedVerification
    case productsUnavailable
    case failed
}

struct WeekFitEntitlementDecision: Equatable, Sendable {
    var state: WeekFitAccessState
    /// Persist only when StoreKit verification produced this state.
    var shouldPersistVerifiedEntitlement: Bool
}
