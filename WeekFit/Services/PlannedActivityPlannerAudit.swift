import Foundation
import OSLog
import SwiftData
import WeekFitPlanner

enum PlannedActivityPlannerAudit {
    private static let logger = Logger(
        subsystem: "WeekFit",
        category: "PlannerDelete"
    )

    static func plannerAction(
        action: String,
        activity: PlannedActivity,
        modelContext: ModelContext
    ) {
        let contextID = ObjectIdentifier(modelContext)
        let persistentID = String(describing: activity.persistentModelID)

        logger.info(
            """
            plannerAction action=\(action, privacy: .public) \
            id=\(activity.id, privacy: .public) \
            title=\(activity.title, privacy: .public) \
            date=\(activity.date.timeIntervalSince1970, privacy: .public) \
            isSkipped=\(activity.isSkipped, privacy: .public) \
            persistentModelID=\(persistentID, privacy: .public) \
            modelContext=\(String(describing: contextID), privacy: .public)
            """
        )

        #if DEBUG
        print(
            "[PlannerDelete] action=\(action) id=\(activity.id) title=\(activity.title) " +
            "date=\(activity.date) isSkipped=\(activity.isSkipped) " +
            "persistentModelID=\(persistentID) modelContext=\(contextID)"
        )
        #endif
    }

    static func deleteTapped(
        itemKind: String,
        activityIDs: [String],
        titles: [String],
        dates: [Date],
        modelContext: ModelContext
    ) {
        let contextID = ObjectIdentifier(modelContext)
        let matchingBeforeDelete = (try? matchingCount(for: activityIDs, in: modelContext)) ?? -1

        logger.info(
            """
            deleteTapped kind=\(itemKind, privacy: .public) \
            ids=\(activityIDs.joined(separator: ","), privacy: .public) \
            titles=\(titles.joined(separator: ","), privacy: .public) \
            dates=\(dates.map { "\($0.timeIntervalSince1970)" }.joined(separator: ","), privacy: .public) \
            modelContext=\(String(describing: contextID), privacy: .public) \
            matchingBeforeDelete=\(matchingBeforeDelete, privacy: .public)
            """
        )

        #if DEBUG
        print(
            "[PlannerDelete] deleteTapped kind=\(itemKind) ids=\(activityIDs) " +
            "matchingBeforeDelete=\(matchingBeforeDelete) modelContext=\(contextID)"
        )
        #endif
    }

    static func fetchVerification(
        phase: String,
        activityID: String,
        count: Int,
        matches: [(title: String, date: Date, isSkipped: Bool)],
        modelContext: ModelContext
    ) {
        let contextID = ObjectIdentifier(modelContext)
        let matchSummary = matches.map {
            "\($0.title)@\($0.date.timeIntervalSince1970):skipped=\($0.isSkipped)"
        }.joined(separator: ";")

        logger.info(
            """
            fetchVerification phase=\(phase, privacy: .public) \
            id=\(activityID, privacy: .public) \
            count=\(count, privacy: .public) \
            matches=\(matchSummary, privacy: .public) \
            modelContext=\(String(describing: contextID), privacy: .public)
            """
        )

        #if DEBUG
        print(
            "[PlannerDelete] fetchVerification phase=\(phase) id=\(activityID) " +
            "count=\(count) matches=[\(matchSummary)] modelContext=\(contextID)"
        )
        #endif
    }

    static func deleteCompleted(
        activityIDs: [String],
        modelContext: ModelContext,
        queryActivityIDs: [String]
    ) {
        let contextID = ObjectIdentifier(modelContext)
        let matchingAfterSave = (try? matchingCount(for: activityIDs, in: modelContext)) ?? -1
        let queryStillContains = activityIDs.filter { queryActivityIDs.contains($0) }

        logger.info(
            """
            deleteCompleted ids=\(activityIDs.joined(separator: ","), privacy: .public) \
            modelContext=\(String(describing: contextID), privacy: .public) \
            matchingAfterSave=\(matchingAfterSave, privacy: .public) \
            queryStillContains=\(queryStillContains.joined(separator: ","), privacy: .public)
            """
        )

        #if DEBUG
        print(
            "[PlannerDelete] deleteCompleted ids=\(activityIDs) matchingAfterSave=\(matchingAfterSave) " +
            "queryStillContains=\(queryStillContains) modelContext=\(contextID)"
        )
        #endif
    }

    static func deleteAborted(reason: String, modelContext: ModelContext) {
        let contextID = ObjectIdentifier(modelContext)
        logger.warning(
            "deleteAborted reason=\(reason, privacy: .public) modelContext=\(String(describing: contextID), privacy: .public)"
        )
        #if DEBUG
        print("[PlannerDelete] deleteAborted reason=\(reason) modelContext=\(contextID)")
        #endif
    }

    static func deleteFailed(ids: [String], error: Error, modelContext: ModelContext) {
        let contextID = ObjectIdentifier(modelContext)
        logger.error(
            """
            deleteFailed ids=\(ids.joined(separator: ","), privacy: .public) \
            error=\(String(describing: error), privacy: .public) \
            modelContext=\(String(describing: contextID), privacy: .public)
            """
        )
        #if DEBUG
        print("[PlannerDelete] deleteFailed ids=\(ids) error=\(error) modelContext=\(contextID)")
        #endif
    }

    private static func matchingCount(for ids: [String], in modelContext: ModelContext) throws -> Int {
        try ids.reduce(into: 0) { partialResult, id in
            partialResult += try PlannedActivityPersistenceService.remainingCount(for: id, in: modelContext)
        }
    }
}
