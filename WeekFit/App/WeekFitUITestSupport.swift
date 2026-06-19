import Foundation

enum WeekFitUITestSupport {
    static let launchArgument = "-ui-testing"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
}
