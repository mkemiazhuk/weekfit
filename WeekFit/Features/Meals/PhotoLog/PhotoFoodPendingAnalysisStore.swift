import Foundation
import UIKit

/// Survives sheet dismiss / app relaunch so the user can return to an in-flight async analysis.
struct PhotoFoodPendingAnalysis: Codable, Equatable, Sendable {
    var analysisId: String
    var captureMethodRaw: String
    var mealSlotRaw: String?
    var createdAt: Date
    var previewJPEG: Data?
}

enum PhotoFoodPendingAnalysisStore {
    private static let key = "weekfit.photoFood.pendingAnalysis.v1"
    private static let defaults = UserDefaults.standard

    static func save(_ pending: PhotoFoodPendingAnalysis) {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> PhotoFoodPendingAnalysis? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PhotoFoodPendingAnalysis.self, from: data)
    }

    static func clear(analysisId: String? = nil) {
        if let analysisId, let current = load(), current.analysisId != analysisId {
            return
        }
        defaults.removeObject(forKey: key)
    }
}
