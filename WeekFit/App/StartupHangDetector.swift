import Foundation
import OSLog

/// DEBUG-only detector for main-run-loop stalls during cold launch.
/// Does **not** terminate the process — logs only, so Xcode can still pause and capture stacks.
enum StartupHangDetector {
    #if DEBUG
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "StartupHang")
    private static let lock = NSLock()
    private static var heartbeatSerial: UInt64 = 0
    private static var lastObservedSerial: UInt64 = 0
    private static var lastProgressAt = CFAbsoluteTimeGetCurrent()
    private static var isArmed = false
    private static var monitorStarted = false
    #endif

    /// Call once when root UI becomes eligible to paint (e.g. ContentView / Root appear).
    static func armForColdLaunch() {
        #if DEBUG
        guard StartupDiagnostics.loggingEnabled else { return }
        lock.lock()
        isArmed = true
        heartbeatSerial = 0
        lastObservedSerial = 0
        lastProgressAt = CFAbsoluteTimeGetCurrent()
        let shouldStart = !monitorStarted
        if shouldStart { monitorStarted = true }
        lock.unlock()

        // Main-run-loop heartbeat — only advances when Main can schedule work.
        DispatchQueue.main.async {
            tickHeartbeat()
        }

        guard shouldStart else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            monitorLoop()
        }
        logger.info(
            "STARTUP HANG DETECTOR armed | launch=\(StartupDiagnostics.launchIDShort, privacy: .public)"
        )
        #endif
    }

    static func disarm() {
        #if DEBUG
        lock.lock()
        isArmed = false
        lock.unlock()
        #endif
    }

    #if DEBUG
    private static func tickHeartbeat() {
        lock.lock()
        let armed = isArmed
        heartbeatSerial &+= 1
        lock.unlock()
        guard armed else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            tickHeartbeat()
        }
    }

    private static func monitorLoop() {
        let thresholds: [(ms: Double, label: String)] = [
            (500, "500ms"),
            (1000, "1s"),
            (2000, "2s")
        ]
        var fired: Set<String> = []

        while true {
            usleep(100_000) // 100ms

            lock.lock()
            let armed = isArmed
            let serial = heartbeatSerial
            let last = lastObservedSerial
            let progressAt = lastProgressAt
            if serial != last {
                lastObservedSerial = serial
                lastProgressAt = CFAbsoluteTimeGetCurrent()
                fired.removeAll()
            }
            let stalledMs = (CFAbsoluteTimeGetCurrent() - lastProgressAt) * 1000
            lock.unlock()

            guard armed else {
                usleep(200_000)
                continue
            }

            // Heartbeat still advancing → main run loop is making progress.
            if serial != last { continue }

            for threshold in thresholds where stalledMs >= threshold.ms && !fired.contains(threshold.label) {
                fired.insert(threshold.label)
                let lastStep = StartupDiagnostics.lastCompletedStep
                let todayStep = TodayStartupDiagnostics.lastCompletedStep
                let message = [
                    "STARTUP HANG DETECTED",
                    "stall=\(threshold.label)",
                    "elapsedStallMs=\(Int(stalledMs))",
                    "launch=\(StartupDiagnostics.launchIDShort)",
                    "lastStartupStep=\(lastStep)",
                    "lastTodayStep=\(todayStep)",
                    "mainHeartbeatSerial=\(serial)",
                    "hint=Pause Xcode now and capture Thread 1 stack"
                ].joined(separator: " | ")
                logger.error("\(message, privacy: .public)")
                StartupDiagnostics.logger.error("\(message, privacy: .public)")
                // Also surface on TodayStartup for single-category filters.
                TodayStartupDiagnostics.logger.error("\(message, privacy: .public)")
            }
        }
    }
    #endif
}
