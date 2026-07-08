import Foundation

enum WeekFitUITestSupport {
    static let launchArgument = "-ui-testing"

    static var isActive: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }
}
