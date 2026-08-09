import Foundation
import SwiftData
import WeekFitPlanner

enum DemoDataMigration {
    private static let completedKey = "weekfit.demoDataMigration_v1_completed"

    /// Removes legacy demo rows that older builds may have written into the production store.
    @discardableResult
    static func cleanupLegacyDemoRecordsIfNeeded(in context: ModelContext) throws -> Int {
        guard !UserDefaults.standard.bool(forKey: completedKey) else {
            StartupDiagnostics.step(4, "migration complete", detail: "DemoDataMigration already completed")
            return 0
        }

        StartupDiagnostics.step(3, "migration start", detail: "DemoDataMigration.fetch legacy demo rows")
        let source = AppReviewDemoStore.sourceIdentifier
        let descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate { activity in
                activity.source == source
            }
        )
        let legacyRows = try context.fetch(descriptor)
        guard !legacyRows.isEmpty else {
            UserDefaults.standard.set(true, forKey: completedKey)
            StartupDiagnostics.step(4, "migration complete", detail: "no legacy demo rows")
            return 0
        }

        for row in legacyRows {
            context.delete(row)
        }
        try context.save()
        UserDefaults.standard.set(true, forKey: completedKey)

        AccountSessionDiagnostics.log(
            "Removed legacy demo rows from production store",
            store: "production",
            demoProviderEnabled: false
        )
        StartupDiagnostics.step(
            4,
            "migration complete",
            detail: "removed legacy demo rows count=\(legacyRows.count)"
        )
        return legacyRows.count
    }

    static func resetMigrationFlagForTests() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
}
