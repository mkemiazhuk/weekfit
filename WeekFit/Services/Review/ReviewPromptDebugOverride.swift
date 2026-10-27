import Foundation

/// Manual debug hook for the system review request.
/// Skips the 5-day, 5-active-day, 5-action, and 7-day engagement gates so one
/// meaningful action can reach `AppStore.requestReview`.
/// Version and 120-day limits still apply. Release builds always return false.
enum ReviewPromptDebugOverride {
    static let launchArgument = "-review-prompt-bypass-thresholds"
    static let defaultsKey = "weekfit.debug.reviewPrompt.bypassThresholds"

    static func bypassesEngagementThresholds(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        #if DEBUG
        if arguments.contains(launchArgument) { return true }
        return defaults.bool(forKey: defaultsKey)
        #else
        _ = defaults
        _ = arguments
        return false
        #endif
    }
}
