import Foundation
internal import Combine

final class ActivityConfirmationState: ObservableObject {

    static let shared = ActivityConfirmationState()

    @Published var pendingActivity: PlannedActivity?
}
