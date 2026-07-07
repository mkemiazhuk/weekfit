import Foundation
import OSLog

enum PlannedActivityPersistenceAudit {
    private static let logger = Logger(
        subsystem: "WeekFit",
        category: "PlannedActivityPersistence"
    )

    static func liveObjectResolved(
        id: String,
        title: String,
        persistentModelID: String,
        isSkipped: Bool,
        auditSource: String
    ) {
        logger.info(
            """
            liveObjectResolved id=\(id, privacy: .public) title=\(title, privacy: .public) \
            persistentModelID=\(persistentModelID, privacy: .public) \
            isSkipped=\(isSkipped, privacy: .public) auditSource=\(auditSource, privacy: .public)
            """
        )
        #if DEBUG
        print(
            "[PlannedActivityPersistence] liveObjectResolved id=\(id) title=\(title) " +
            "persistentModelID=\(persistentModelID) isSkipped=\(isSkipped)"
        )
        #endif
    }

    static func deleteMissing(id: String, auditSource: String) {
        logger.warning(
            "deleteMissing id=\(id, privacy: .public) auditSource=\(auditSource, privacy: .public)"
        )
    }

    static func deleteRequested(
        id: String,
        title: String,
        type: String,
        source: String,
        auditSource: String
    ) {
        logger.info(
            "deleteRequested id=\(id, privacy: .public) title=\(title, privacy: .public) type=\(type, privacy: .public) source=\(source, privacy: .public) auditSource=\(auditSource, privacy: .public)"
        )
    }

    static func waterGroupDeleteRequested(count: Int, ids: [String], auditSource: String) {
        logger.info(
            "waterGroupDeleteRequested count=\(count, privacy: .public) ids=\(ids.joined(separator: ","), privacy: .public) auditSource=\(auditSource, privacy: .public)"
        )
    }

    static func contextDeleted(id: String) {
        logger.info("contextDeleted id=\(id, privacy: .public)")
    }

    static func saveAttempted(idCount: Int) {
        logger.info("saveAttempted idCount=\(idCount, privacy: .public)")
    }

    static func saveCompleted(idCount: Int) {
        logger.info("saveCompleted idCount=\(idCount, privacy: .public)")
    }

    static func saveFailed(idCount: Int, error: Error) {
        logger.error(
            "saveFailed idCount=\(idCount, privacy: .public) error=\(String(describing: error), privacy: .public)"
        )
    }

    static func fetchAfterSave(id: String, remainingCount: Int) {
        logger.info(
            "fetchAfterSave id=\(id, privacy: .public) remainingCount=\(remainingCount, privacy: .public)"
        )
    }

    static func notificationCleanupStarted(id: String) {
        logger.info("notificationCleanupStarted id=\(id, privacy: .public)")
    }

    static func notificationCleanupCompleted(id: String) {
        logger.info("notificationCleanupCompleted id=\(id, privacy: .public)")
    }

    static func notificationCleanupFailed(id: String, error: Error) {
        logger.error(
            "notificationCleanupFailed id=\(id, privacy: .public) error=\(String(describing: error), privacy: .public)"
        )
    }
}
