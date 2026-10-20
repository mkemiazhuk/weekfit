import Foundation
import OSLog

/// Sanitized photo-recognition diagnostics. Never log tokens, images, base64, or raw JSON bodies.
enum PhotoFoodDiagnostics {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "PhotoFoodFlow")

    struct AnalysisClock: Sendable {
        let analysisId: String
        private let startedAt: ContinuousClock.Instant

        init(analysisId: String = UUID().uuidString.lowercased()) {
            self.analysisId = analysisId
            self.startedAt = ContinuousClock.now
        }

        var elapsedMs: Int {
            let elapsed = ContinuousClock.now - startedAt
            return Int(elapsed.components.seconds * 1000)
                + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        }
    }

    static func event(_ name: String, clock: AnalysisClock, detail: String? = nil) {
        #if DEBUG
        if let detail {
            logger.info(
                "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=\(name, privacy: .public) detail=\(detail, privacy: .public)"
            )
        } else {
            logger.info(
                "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=\(name, privacy: .public)"
            )
        }
        #else
        _ = name
        _ = clock
        _ = detail
        #endif
    }

    static func stage(_ stage: String, clock: AnalysisClock, durationMs: Int? = nil) {
        #if DEBUG
        if let durationMs {
            logger.info(
                "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms stage=\(stage, privacy: .public) durationMs=\(durationMs, privacy: .public)"
            )
        } else {
            logger.info(
                "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms stage=\(stage, privacy: .public)"
            )
        }
        #else
        _ = stage
        _ = clock
        _ = durationMs
        #endif
    }

    static func http(
        clock: AnalysisClock,
        status: Int,
        responseBytes: Int,
        requestId: String?,
        durationMs: Int
    ) {
        #if DEBUG
        logger.info(
            "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=http status=\(status, privacy: .public) responseBytes=\(responseBytes, privacy: .public) requestId=\(requestId ?? "-", privacy: .public) durationMs=\(durationMs, privacy: .public)"
        )
        #else
        _ = clock
        _ = status
        _ = responseBytes
        _ = requestId
        _ = durationMs
        #endif
    }

    static func decodeSuccess(
        clock: AnalysisClock,
        itemCount: Int,
        isFood: Bool,
        requiresConfirmation: Bool,
        requestId: String?,
        durationMs: Int
    ) {
        #if DEBUG
        logger.info(
            "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=decodeOk items=\(itemCount, privacy: .public) isFood=\(isFood, privacy: .public) requiresConfirmation=\(requiresConfirmation, privacy: .public) requestId=\(requestId ?? "-", privacy: .public) durationMs=\(durationMs, privacy: .public)"
        )
        #else
        _ = clock
        _ = itemCount
        _ = isFood
        _ = requiresConfirmation
        _ = requestId
        _ = durationMs
        #endif
    }

    static func decodeFailure(clock: AnalysisClock, error: Error, durationMs: Int) {
        if let decoding = error as? DecodingError {
            logger.error(
                "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=decodeFail kind=\(decodingKind(decoding), privacy: .public) path=\(codingPath(decoding), privacy: .public) durationMs=\(durationMs, privacy: .public)"
            )
            return
        }
        logger.error(
            "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=decodeFail type=\(String(describing: type(of: error)), privacy: .public) durationMs=\(durationMs, privacy: .public)"
        )
    }

    static func validationFailure(clock: AnalysisClock, error: PhotoFoodRecognitionError) {
        logger.error(
            "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=validateFail reason=\(String(describing: error), privacy: .public)"
        )
    }

    static func stateTransition(clock: AnalysisClock, from: String, to: String) {
        #if DEBUG
        logger.info(
            "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=state from=\(from, privacy: .public) to=\(to, privacy: .public)"
        )
        #else
        _ = clock
        _ = from
        _ = to
        #endif
    }

    static func cancelled(clock: AnalysisClock, at: String) {
        logger.warning(
            "id=\(clock.analysisId, privacy: .public) t=\(clock.elapsedMs, privacy: .public)ms event=cancelled at=\(at, privacy: .public)"
        )
    }

    static func skippedApply(clock: AnalysisClock?, reason: String) {
        let id = clock?.analysisId ?? "-"
        let t = clock?.elapsedMs ?? -1
        logger.warning(
            "id=\(id, privacy: .public) t=\(t, privacy: .public)ms event=skipApply reason=\(reason, privacy: .public)"
        )
    }

    // MARK: - DecodingError (sanitized)

    private static func decodingKind(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch: return "typeMismatch"
        case .valueNotFound: return "valueNotFound"
        case .keyNotFound: return "keyNotFound"
        case .dataCorrupted: return "dataCorrupted"
        @unknown default: return "unknown"
        }
    }

    private static func codingPath(_ error: DecodingError) -> String {
        let path: [CodingKey]
        switch error {
        case .typeMismatch(_, let context),
             .valueNotFound(_, let context),
             .keyNotFound(_, let context),
             .dataCorrupted(let context):
            path = context.codingPath
        @unknown default:
            return ""
        }
        if path.isEmpty { return "<root>" }
        return path.map { key in
            if let int = key.intValue { return "[\(int)]" }
            return key.stringValue
        }.joined(separator: ".")
    }
}
