import Foundation
import SwiftData
import WeekFitPlanner

enum WeekFitModelContainer {
    static let production: ModelContainer = makeProductionContainer()
    static let reviewDemo: ModelContainer = makeReviewDemoContainer()

    /// Backward-compatible alias for production store.
    static var shared: ModelContainer { production }

    static func productionContext() -> ModelContext {
        ModelContext(production)
    }

    static func reviewDemoContext() -> ModelContext {
        ModelContext(reviewDemo)
    }

    private static func makeProductionContainer() -> ModelContainer {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("Application Support directory is unavailable.")
        }

        do {
            try fileManager.createDirectory(
                at: appSupport,
                withIntermediateDirectories: true
            )

            let storeURL = appSupport.appendingPathComponent("default.store")
            let configuration = ModelConfiguration(url: storeURL)
            return try ModelContainer(
                for: PlannedActivity.self,
                configurations: configuration
            )
        } catch {
            fatalError("Could not create production ModelContainer: \(error)")
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
            fatalError("Could not create review demo ModelContainer: \(error)")
        }
    }
}
