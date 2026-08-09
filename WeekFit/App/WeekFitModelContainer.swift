import Foundation
import SwiftData
import WeekFitPlanner

enum WeekFitModelContainer {
    /// Non-nil when the on-disk production store could not be opened.
    /// The process keeps an in-memory fallback so UI can show a diagnostic screen
    /// instead of `fatalError`. The on-disk store is never deleted.
    private(set) static var productionLoadFailure: PersistenceLoadFailure?

    static let production: ModelContainer = makeProductionContainer()
    static let reviewDemo: ModelContainer = makeReviewDemoContainer()

    /// Backward-compatible alias for production store.
    static var shared: ModelContainer { production }

    static var didFailToLoadProductionStore: Bool {
        productionLoadFailure != nil
    }

    static func productionContext() -> ModelContext {
        ModelContext(production)
    }

    static func reviewDemoContext() -> ModelContext {
        ModelContext(reviewDemo)
    }

    struct PersistenceLoadFailure: Sendable {
        let message: String
        let storeURL: URL?
        let storeExisted: Bool?
        let storeByteCount: Int?
        let errorDescription: String
        let errorDomain: String?
        let errorCode: Int?
    }

    private static func makeProductionContainer() -> ModelContainer {
        StartupDiagnostics.step(2, "persistence init", detail: "begin production ModelContainer")

        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            let failure = PersistenceLoadFailure(
                message: "Application Support directory is unavailable.",
                storeURL: nil,
                storeExisted: nil,
                storeByteCount: nil,
                errorDescription: "Application Support directory is unavailable.",
                errorDomain: nil,
                errorCode: nil
            )
            productionLoadFailure = failure
            StartupDiagnostics.failed(
                operation: "locateApplicationSupport",
                error: NSError(
                    domain: "com.weekfit.app.persistence",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: failure.message]
                ),
                step: 2
            )
            return makeInMemoryFallback(reason: failure.message)
        }

        let storeURL = appSupport.appendingPathComponent("default.store")
        let storeExisted = fileManager.fileExists(atPath: storeURL.path)
        let storeByteCount = (try? storeURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize

        StartupDiagnostics.step(
            2,
            "persistence init",
            detail: "url=\(storeURL.path) existed=\(storeExisted) bytes=\(storeByteCount.map(String.init) ?? "unknown")"
        )

        do {
            try fileManager.createDirectory(
                at: appSupport,
                withIntermediateDirectories: true
            )

            let configuration = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(
                for: PlannedActivity.self,
                configurations: configuration
            )
            productionLoadFailure = nil
            StartupDiagnostics.step(2, "persistence init", detail: "production ModelContainer ready")
            return container
        } catch {
            let nsError = error as NSError
            let failure = PersistenceLoadFailure(
                message: "Could not create production ModelContainer.",
                storeURL: storeURL,
                storeExisted: storeExisted,
                storeByteCount: storeByteCount,
                errorDescription: nsError.localizedDescription,
                errorDomain: nsError.domain,
                errorCode: nsError.code
            )
            productionLoadFailure = failure
            StartupDiagnostics.failed(
                operation: "createProductionModelContainer",
                error: error,
                step: 2,
                extras: [
                    "storeURL": storeURL.path,
                    "storeExisted": String(storeExisted),
                    "storeBytes": storeByteCount.map(String.init) ?? "unknown",
                    "note": "on-disk store was NOT deleted; using in-memory fallback for diagnostics only"
                ]
            )
            return makeInMemoryFallback(reason: failure.errorDescription)
        }
    }

    private static func makeReviewDemoContainer() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(
                for: PlannedActivity.self,
                configurations: configuration
            )
        } catch {
            StartupDiagnostics.failed(
                operation: "createReviewDemoModelContainer",
                error: error,
                step: 2
            )
            return makeInMemoryFallback(reason: "review demo ModelContainer failed: \(error)")
        }
    }

    private static func makeInMemoryFallback(reason: String) -> ModelContainer {
        StartupDiagnostics.step(
            2,
            "persistence init",
            detail: "IN-MEMORY FALLBACK (diagnostic only; no store wipe). reason=\(reason)"
        )
        do {
            return try ModelContainer(
                for: PlannedActivity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            StartupDiagnostics.failed(
                operation: "createInMemoryFallbackModelContainer",
                error: error,
                step: 2
            )
            // If even in-memory fails, the process cannot continue meaningfully.
            preconditionFailure(
                "WeekFit could not create an in-memory ModelContainer fallback: \(error)"
            )
        }
    }
}
