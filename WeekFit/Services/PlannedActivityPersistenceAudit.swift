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
        #if DEBUG
        logger.debug(
            """
            liveObjectResolved id=\(id, privacy: .public) title=\(title, privacy: .public) \
            persistentModelID=\(persistentModelID, privacy: .public) \
            isSkipped=\(isSkipped, privacy: .public) auditSource=\(auditSource, privacy: .public)
            """
        )
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
        #if DEBUG
        logger.debug(
            "deleteRequested id=\(id, privacy: .public) title=\(title, privacy: .public) type=\(type, privacy: .public) source=\(source, privacy: .public) auditSource=\(auditSource, privacy: .public)"
        )
        #endif
    }

    static func waterGroupDeleteRequested(count: Int, ids: [String], auditSource: String) {
        #if DEBUG
        logger.debug(
            "waterGroupDeleteRequested count=\(count, privacy: .public) ids=\(ids.joined(separator: ","), privacy: .public) auditSource=\(auditSource, privacy: .public)"
        )
        #endif
    }

    static func contextDeleted(id: String) {
        #if DEBUG
        logger.debug("contextDeleted id=\(id, privacy: .public)")
        #endif
    }

    static func saveAttempted(idCount: Int) {
        #if DEBUG
        logger.debug("saveAttempted idCount=\(idCount, privacy: .public)")
        #endif
    }

    static func saveCompleted(idCount: Int) {
        #if DEBUG
        logger.debug("saveCompleted idCount=\(idCount, privacy: .public)")
        #endif
    }

    static func saveFailed(idCount: Int, error: Error) {
        logger.error(
            "saveFailed idCount=\(idCount, privacy: .public) error=\(String(describing: error), privacy: .public)"
        )
    }

    static func fetchAfterSave(id: String, remainingCount: Int) {
        #if DEBUG
        logger.debug(
            "fetchAfterSave id=\(id, privacy: .public) remainingCount=\(remainingCount, privacy: .public)"
        )
        #endif
    }

    static func notificationCleanupStarted(id: String) {
        #if DEBUG
        logger.debug("notificationCleanupStarted id=\(id, privacy: .public)")
        #endif
    }

    static func notificationCleanupCompleted(id: String) {
        #if DEBUG
        logger.debug("notificationCleanupCompleted id=\(id, privacy: .public)")
        #endif
    }

    static func notificationCleanupFailed(id: String, error: Error) {
        logger.error(
            "notificationCleanupFailed id=\(id, privacy: .public) error=\(String(describing: error), privacy: .public)"
        )
    }
}
