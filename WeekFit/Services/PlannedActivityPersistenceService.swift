import Foundation
import SwiftData

enum PlannedActivityPersistenceError: Error, Equatable {
    case activityNotFound(activityID: String)
    case activityIsSkipped(activityID: String)
    case saveFailed(activityIDs: [String])
    case verifyFailed(activityID: String, remainingCount: Int)

    static func == (lhs: PlannedActivityPersistenceError, rhs: PlannedActivityPersistenceError) -> Bool {
        switch (lhs, rhs) {
        case (.activityNotFound(let left), .activityNotFound(let right)):
            return left == right
        case (.activityIsSkipped(let left), .activityIsSkipped(let right)):
            return left == right
        case (.saveFailed(let left), .saveFailed(let right)):
            return left == right
        case (.verifyFailed(let leftID, let leftCount), .verifyFailed(let rightID, let rightCount)):
            return leftID == rightID && leftCount == rightCount
        default:
            return false
        }
    }
}

struct PlannedActivityDeleteSnapshot: Sendable {
    let id: String
    let title: String
    let type: String
    let source: String
    let date: Date
    let healthKitWorkoutUUID: String?

    init(activity: PlannedActivity) {
        id = activity.id
        title = activity.title
        type = activity.type
        source = activity.source
        date = activity.date
        healthKitWorkoutUUID = activity.healthKitWorkoutUUID
    }

    var notificationTarget: DeletedActivityNotificationTarget {
        DeletedActivityNotificationTarget(id: id, title: title, date: date)
    }
}

@MainActor
enum PlannedActivityPersistenceService {
    #if DEBUG
    static var notificationCleanupHandler: ((PlannedActivityDeleteSnapshot) async -> Void)?
    static var onSaveForTesting: (() -> Void)?
    #endif

    @discardableResult
    static func deleteActivities(
        _ activities: [PlannedActivity],
        modelContext: ModelContext,
        auditSource: String
    ) throws -> [PlannedActivityDeleteSnapshot] {
        try deleteActivities(
            withIDs: activities.map(\.id),
            modelContext: modelContext,
            auditSource: auditSource
        )
    }

    @discardableResult
    static func deleteActivities(
        withIDs ids: [String],
        modelContext: ModelContext,
        auditSource: String
    ) throws -> [PlannedActivityDeleteSnapshot] {
        let uniqueIDs = Array(Set(ids))
        guard !uniqueIDs.isEmpty else { return [] }

        var snapshots: [PlannedActivityDeleteSnapshot] = []
        var activitiesToDelete: [PlannedActivity] = []
        snapshots.reserveCapacity(uniqueIDs.count)
        activitiesToDelete.reserveCapacity(uniqueIDs.count)

        for id in uniqueIDs {
            guard let activity = try fetchActivity(id: id, in: modelContext) else {
                PlannedActivityPersistenceAudit.deleteMissing(id: id, auditSource: auditSource)
                throw PlannedActivityPersistenceError.activityNotFound(activityID: id)
            }

            PlannedActivityPersistenceAudit.liveObjectResolved(
                id: activity.id,
                title: activity.title,
                persistentModelID: String(describing: activity.persistentModelID),
                isSkipped: activity.isSkipped,
                auditSource: auditSource
            )

            guard !activity.isSkipped else {
                throw PlannedActivityPersistenceError.activityIsSkipped(activityID: activity.id)
            }

            let snapshot = PlannedActivityDeleteSnapshot(activity: activity)
            snapshots.append(snapshot)
            activitiesToDelete.append(activity)
        }

        if snapshots.count > 1 {
            PlannedActivityPersistenceAudit.waterGroupDeleteRequested(
                count: snapshots.count,
                ids: snapshots.map(\.id),
                auditSource: auditSource
            )
        }

        for snapshot in snapshots {
            PlannedActivityPersistenceAudit.deleteRequested(
                id: snapshot.id,
                title: snapshot.title,
                type: snapshot.type,
                source: snapshot.source,
                auditSource: auditSource
            )
        }

        for activity in activitiesToDelete {
            DismissedHealthKitWorkoutStore.recordDeletion(of: activity)
            modelContext.delete(activity)
            PlannedActivityPersistenceAudit.contextDeleted(id: activity.id)
        }

        PlannedActivityPersistenceAudit.saveAttempted(idCount: snapshots.count)

        do {
            #if DEBUG
            onSaveForTesting?()
            #endif
            try modelContext.save()
        } catch {
            PlannedActivityPersistenceAudit.saveFailed(idCount: snapshots.count, error: error)
            throw PlannedActivityPersistenceError.saveFailed(activityIDs: snapshots.map(\.id))
        }

        PlannedActivityPersistenceAudit.saveCompleted(idCount: snapshots.count)

        for snapshot in snapshots {
            let remainingCount = try remainingCount(for: snapshot.id, in: modelContext)
            PlannedActivityPersistenceAudit.fetchAfterSave(
                id: snapshot.id,
                remainingCount: remainingCount
            )

            guard remainingCount == 0 else {
                throw PlannedActivityPersistenceError.verifyFailed(
                    activityID: snapshot.id,
                    remainingCount: remainingCount
                )
            }
        }

        scheduleNotificationCleanup(for: snapshots)
        return snapshots
    }

    static func fetchActivity(id: String, in modelContext: ModelContext) throws -> PlannedActivity? {
        let targetID = id
        var descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate { activity in
                activity.id == targetID
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    static func remainingCount(for activityID: String, in modelContext: ModelContext) throws -> Int {
        let targetID = activityID
        let descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate { activity in
                activity.id == targetID
            }
        )
        return try modelContext.fetchCount(descriptor)
    }

    private static func scheduleNotificationCleanup(for snapshots: [PlannedActivityDeleteSnapshot]) {
        Task {
            for snapshot in snapshots {
                PlannedActivityPersistenceAudit.notificationCleanupStarted(id: snapshot.id)

                #if DEBUG
                if let notificationCleanupHandler {
                    await notificationCleanupHandler(snapshot)
                } else {
                    await ActivityNotificationService.shared.cancelNotificationsForDeletedActivity(
                        snapshot.notificationTarget
                    )
                }
                #else
                await ActivityNotificationService.shared.cancelNotificationsForDeletedActivity(
                    snapshot.notificationTarget
                )
                #endif

                PlannedActivityPersistenceAudit.notificationCleanupCompleted(id: snapshot.id)
            }
        }
    }
}

struct DeletedActivityNotificationTarget: Sendable {
    let id: String
    let title: String
    let date: Date
}
