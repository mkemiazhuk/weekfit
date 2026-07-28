import Foundation

extension Notification.Name {
    static let weekfitMeaningfulAction = Notification.Name("weekfit.review.meaningfulAction")
}

enum ReviewEngagement {
    static let actionUserInfoKey = "action"

    /// Fire-and-forget engagement signal for call sites without DI access.
    @MainActor
    static func record(_ action: MeaningfulAction) {
        NotificationCenter.default.post(
            name: .weekfitMeaningfulAction,
            object: nil,
            userInfo: [actionUserInfoKey: action.rawValue]
        )
    }
}
