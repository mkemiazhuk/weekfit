import Foundation

/// How long heat/sauna sessions own the Coach story after they end.
enum CoachHeatRecoveryPolicy {
    /// Cool-down guidance window — matches copy (“остыньте”, ~15–30 min) with a small buffer.
    static let focusWindowMinutes = 45
}
