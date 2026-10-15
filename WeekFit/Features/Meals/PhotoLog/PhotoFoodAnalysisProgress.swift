import Foundation

/// UI progress mirrors real client stages only — never invented model substeps.
enum PhotoFoodAnalysisProgress: Equatable, Sendable {
    case preparing
    case authenticating
    case uploading
    /// Server accepted the job; waiting in the durable queue.
    case queued
    /// A worker is running the AI analysis.
    case processing
    case waiting
    /// Same network wait, after 10s of silence from the client’s perspective.
    case waitingLong

    var messageKey: String {
        switch self {
        case .preparing: return "today.photoLog.analyzing.stage.preparing"
        case .authenticating: return "today.photoLog.analyzing.stage.authenticating"
        case .uploading: return "today.photoLog.analyzing.stage.uploading"
        case .queued: return "today.photoLog.analyzing.stage.queued"
        case .processing: return "today.photoLog.analyzing.stage.processing"
        case .waiting: return "today.photoLog.analyzing.stage.waiting"
        case .waitingLong: return "today.photoLog.analyzing.stage.waitingLong"
        }
    }
}

enum PhotoFoodNetworkStage: String, Sendable {
    case authenticating
    case uploading
    case queued
    case processing
    case waitingForResponse
}
