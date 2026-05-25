import Foundation
internal import Combine

final class AppSessionState: ObservableObject {

    @Published var returnToTodayTrigger = UUID()
    @Published var healthRefreshTrigger = UUID()

    func triggerReturnToToday() {
        returnToTodayTrigger = UUID()
    }

    func triggerHealthRefresh() {
        healthRefreshTrigger = UUID()
    }
}
