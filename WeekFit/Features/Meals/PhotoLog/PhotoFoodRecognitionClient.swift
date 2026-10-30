import Foundation
import UIKit

protocol PhotoFoodRecognizing: Sendable {
    func recognizeFood(
        imageJPEG: Data,
        note: String?,
        analysisId: String,
        onStage: @escaping @Sendable (PhotoFoodNetworkStage) -> Void
    ) async throws -> PhotoFoodAPIResponse
}

/// Live client: async `POST /v1/food/photo-analyze` + status polling.
/// HTTP is not held open for the full AI duration. Never embeds OpenAI keys.
struct PhotoFoodRecognitionClient: PhotoFoodRecognizing {
    /// End-to-end budget including queue wait + AI (server AI ≤90s) + upload/poll margin.
    static let overallDeadlineSeconds: TimeInterval = 180
    /// Accept may complete inline when capacity is free (result in the same response).
    static let acceptTimeoutSeconds: TimeInterval = 90
    static let pollTimeoutSeconds: TimeInterval = 10

    /// App language for recognition copy — not device region.
    static func recognitionLocaleIdentifier() -> String {
        // Refresh in case recognition runs before AppLanguageManager has synced cache.
        WeekFitWarmLocalizationCache()
        return WeekFitCurrentAppLanguage().rawValue
    }

    private static let sharedUploadSession = PhotoFoodUploadSession()

    var session: URLSession = sharedUploadSession.session
    var uploadSession: PhotoFoodUploadSession = sharedUploadSession
    var baseURLOverride: URL?
    var authTokenOverride: String?
    /// Injected for tests; production uses Firebase ID tokens.
    var tokenProvider: (@Sendable (_ forceRefresh: Bool) async throws -> String)?
    /// Injected for tests; production reads StoreKit paid-subscription JWS.
    var paidSubscriptionJWSProvider: (@Sendable () async -> String?)?

    func recognizeFood(
        imageJPEG: Data,
        note: String? = nil,
        analysisId: String,
        onStage: @escaping @Sendable (PhotoFoodNetworkStage) -> Void
    ) async throws -> PhotoFoodAPIResponse {
        let clock = PhotoFoodDiagnostics.AnalysisClock(analysisId: analysisId)
        if WeekFitAIBilling.refused {
            throw PhotoFoodRecognitionError.sandboxMisconfigured
        }
        if WeekFitAIBilling.enabled {
            guard imageJPEG.count > 64, imageJPEG.count <= PhotoFoodImagePreparer.maxUploadBytes else {
                throw PhotoFoodRecognitionError.invalidImage
            }
            onStage(.authenticating)
            let body = PhotoFoodRecognizeRequest(imageBase64: imageJPEG.base64EncodedString(),
                mimeType: "image/jpeg", locale: Self.recognitionLocaleIdentifier(), note: note)
            do {
                onStage(.uploading)
                return try await WeekFitAIClient(baseURL: baseURLOverride ?? WeekFitCloudAPI.foodPhotoBaseURL)
                    .request(path: "v2/ai/photo", body: JSONEncoder().encode(body), idempotencyKey: analysisId)
            } catch WeekFitAIUsageError.subscriptionRequired {
                throw PhotoFoodRecognitionError.subscriptionRequired
            } catch WeekFitAIUsageError.quotaExhausted {
                throw PhotoFoodRecognitionError.quotaExhausted
            } catch is CancellationError {
                throw PhotoFoodRecognitionError.cancelled
            } catch {
                throw PhotoFoodRecognitionError.unavailable
            }
        }
        guard imageJPEG.count > 64, imageJPEG.count <= PhotoFoodImagePreparer.maxUploadBytes else {
            throw PhotoFoodRecognitionError.invalidImage
        }

        let baseURL = baseURLOverride ?? WeekFitCloudAPI.foodPhotoBaseURL
        let acceptURL = baseURL.appending(path: "v1/food/photo-analyze")
        PhotoFoodDiagnostics.event(
            "recognizeStart",
            clock: clock,
            detail: "host=\(baseURL.host ?? "nil") jpegBytes=\(imageJPEG.count) mode=async"
        )

        return try await withThrowingTaskGroup(of: PhotoFoodAPIResponse.self) { group in
            group.addTask {
                try await self.recognizeWithinDeadline(
                    baseURL: baseURL,
                    acceptURL: acceptURL,
                    imageJPEG: imageJPEG,
                    note: note,
                    clock: clock,
                    onStage: onStage
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.overallDeadlineSeconds))
                PhotoFoodDiagnostics.event("overallDeadline", clock: clock)
                throw PhotoFoodRecognitionError.timedOut
            }
            guard let first = try await group.next() else {
                throw PhotoFoodRecognitionError.network
            }
            group.cancelAll()
            return first
        }
    }

    // MARK: - Private

    private func recognizeWithinDeadline(
        baseURL: URL,
        acceptURL: URL,
        imageJPEG: Data,
        note: String?,
        clock: PhotoFoodDiagnostics.AnalysisClock,
        onStage: @escaping @Sendable (PhotoFoodNetworkStage) -> Void
    ) async throws -> PhotoFoodAPIResponse {
        let authStarted = clock.elapsedMs
        onStage(.authenticating)
        PhotoFoodDiagnostics.stage("auth", clock: clock)
        // Auth + paid/free-trial proof are independent — run in parallel.
        async let tokenTask = resolveToken(forceRefresh: false)
        async let proofTask = resolveSubscriptionAccess()
        let firstToken = try await tokenTask
        let access = try await proofTask
        PhotoFoodDiagnostics.stage("auth", clock: clock, durationMs: clock.elapsedMs - authStarted)
        PhotoFoodDiagnostics.event(
            "subscriptionProof",
            clock: clock,
            detail: access.diagnosticsLabel
        )

        do {
            let response = try await performAsyncRecognize(
                baseURL: baseURL,
                acceptURL: acceptURL,
                imageJPEG: imageJPEG,
                note: note,
                bearer: firstToken,
                access: access,
                clock: clock,
                onStage: onStage
            )
            Self.consumeFreeTrialIfNeeded(access)
            return response
        } catch PhotoFoodRecognitionError.unauthorized {
            // Single forced refresh + retry of accept only. No infinite loops.
            let refreshStarted = clock.elapsedMs
            onStage(.authenticating)
            PhotoFoodDiagnostics.stage("authRefresh", clock: clock)
            let refreshed = try await resolveToken(forceRefresh: true)
            PhotoFoodDiagnostics.stage(
                "authRefresh",
                clock: clock,
                durationMs: clock.elapsedMs - refreshStarted
            )
            let response = try await performAsyncRecognize(
                baseURL: baseURL,
                acceptURL: acceptURL,
                imageJPEG: imageJPEG,
                note: note,
                bearer: refreshed,
                access: access,
                clock: clock,
                onStage: onStage
            )
            Self.consumeFreeTrialIfNeeded(access)
            return response
        } catch PhotoFoodRecognitionError.subscriptionRequired {
            // Server rejected free trial (already claimed for this UID) — sync local UX gate.
            if case .freeTrial = access {
                PhotoFoodFreeTrialStore.markConsumed()
            }
            throw PhotoFoodRecognitionError.subscriptionRequired
        }
    }

    private enum SubscriptionAccess: Equatable {
        case paidJWS(String)
        case freeTrial

        var diagnosticsLabel: String {
            switch self {
            case .paidJWS: return "paid"
            case .freeTrial: return "free_trial"
            }
        }
    }

    private func resolveSubscriptionAccess() async throws -> SubscriptionAccess {
        if let paidSubscriptionJWSProvider {
            if let jws = await paidSubscriptionJWSProvider(), !jws.isEmpty {
                return .paidJWS(jws)
            }
            if PhotoFoodFreeTrialStore.hasRemaining {
                return .freeTrial
            }
            throw PhotoFoodRecognitionError.subscriptionRequired
        }
        #if DEBUG
        if let host = (baseURLOverride ?? WeekFitCloudAPI.configuredBaseURL)?.host,
           host == "localhost" || host.hasPrefix("127.") || host.hasPrefix("192.168.") || host.hasPrefix("10.") {
            // Local backend with ALLOW_DEV_AUTH skips StoreKit proof.
            return .paidJWS("weekfit-dev-local-subscription")
        }
        #endif
        if let jws = await WeekFitPaidSubscriptionProof.currentPaidSubscriptionJWS(), !jws.isEmpty {
            return .paidJWS(jws)
        }
        if PhotoFoodFreeTrialStore.hasRemaining {
            return .freeTrial
        }
        throw PhotoFoodRecognitionError.subscriptionRequired
    }

    private static func consumeFreeTrialIfNeeded(_ access: SubscriptionAccess) {
        guard case .freeTrial = access else { return }
        PhotoFoodFreeTrialStore.markConsumed()
    }

    private func resolveToken(forceRefresh: Bool) async throws -> String {
        if let authTokenOverride, !authTokenOverride.isEmpty {
            return authTokenOverride
        }
        if let tokenProvider {
            return try await tokenProvider(forceRefresh)
        }
        #if DEBUG
        if let host = (baseURLOverride ?? WeekFitCloudAPI.configuredBaseURL)?.host,
           host == "localhost" || host.hasPrefix("127.") || host.hasPrefix("192.168.") || host.hasPrefix("10.") {
            return WeekFitCloudAPI.debugDevToken
        }
        #endif
        do {
            return try await PhotoFoodFirebaseAuth.idToken(forcingRefresh: forceRefresh)
        } catch PhotoFoodFirebaseAuth.AuthFailure.firebaseNotConfigured {
            throw PhotoFoodRecognitionError.notConfigured
        } catch PhotoFoodFirebaseAuth.AuthFailure.authConfigurationMissing {
            throw PhotoFoodRecognitionError.authUnavailable
        } catch PhotoFoodFirebaseAuth.AuthFailure.signInFailed {
            throw PhotoFoodRecognitionError.authUnavailable
        } catch {
            throw PhotoFoodRecognitionError.unauthorized
        }
    }

    private func performAsyncRecognize(
        baseURL: URL,
        acceptURL: URL,
        imageJPEG: Data,
        note: String?,
        bearer: String,
        access: SubscriptionAccess,
        clock: PhotoFoodDiagnostics.AnalysisClock,
        onStage: @escaping @Sendable (PhotoFoodNetworkStage) -> Void
    ) async throws -> PhotoFoodAPIResponse {
        var request = URLRequest(url: acceptURL)
        request.httpMethod = "POST"
        // Accept timeout covers upload + durable enqueue only — not AI processing.
        request.timeoutInterval = Self.acceptTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        applySubscriptionAccess(access, to: &request)
        request.setValue(clock.analysisId, forHTTPHeaderField: "Idempotency-Key")
        request.setValue(clock.analysisId, forHTTPHeaderField: "X-WeekFit-Analysis-Id")

        let encodeStarted = clock.elapsedMs
        let body = PhotoFoodRecognizeRequest(
            imageBase64: imageJPEG.base64EncodedString(),
            mimeType: "image/jpeg",
            locale: PhotoFoodRecognitionClient.recognitionLocaleIdentifier(),
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        request.httpBody = try JSONEncoder().encode(body)
        PhotoFoodDiagnostics.stage(
            "encode",
            clock: clock,
            durationMs: clock.elapsedMs - encodeStarted
        )

        onStage(.uploading)
        PhotoFoodDiagnostics.stage("upload", clock: clock)
        let uploadStarted = clock.elapsedMs
        let uploadHandlerID = uploadSession.onUploadFinished {
            onStage(.queued)
            PhotoFoodDiagnostics.stage("queued", clock: clock, durationMs: nil)
        }
        defer { uploadSession.removeUploadFinishedHandler(uploadHandlerID) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            PhotoFoodDiagnostics.cancelled(clock: clock, at: "URLSession.CancellationError")
            throw PhotoFoodRecognitionError.cancelled
        } catch let urlError as URLError where urlError.code == .cancelled {
            PhotoFoodDiagnostics.cancelled(clock: clock, at: "URLSession.URLError.cancelled")
            throw PhotoFoodRecognitionError.cancelled
        } catch let urlError as URLError where urlError.code == .timedOut {
            PhotoFoodDiagnostics.event("httpTimedOut", clock: clock)
            throw PhotoFoodRecognitionError.timedOut
        } catch {
            PhotoFoodDiagnostics.event(
                "httpNetwork",
                clock: clock,
                detail: String(describing: type(of: error))
            )
            throw PhotoFoodRecognitionError.network
        }

        guard let http = response as? HTTPURLResponse else {
            PhotoFoodDiagnostics.event("httpNonHTTP", clock: clock)
            throw PhotoFoodRecognitionError.invalidResponse
        }

        PhotoFoodDiagnostics.http(
            clock: clock,
            status: http.statusCode,
            responseBytes: data.count,
            requestId: clock.analysisId,
            durationMs: clock.elapsedMs - uploadStarted
        )

        // 200 = idempotent completed replay; 202 = accepted into durable queue.
        if http.statusCode == 200 {
            if let accept = try? JSONDecoder().decode(PhotoFoodAsyncAccept.self, from: data),
               accept.status == "completed",
               let result = accept.result {
                try PhotoFoodAPIResponseValidator.validate(result)
                PhotoFoodPendingAnalysisStore.clear(analysisId: accept.analysisId)
                return result
            }
        }

        if http.statusCode == 202 || http.statusCode == 200 {
            let accept = try JSONDecoder().decode(PhotoFoodAsyncAccept.self, from: data)
            let analysisId = accept.analysisId
            PhotoFoodPendingAnalysisStore.save(
                PhotoFoodPendingAnalysis(
                    analysisId: analysisId,
                    captureMethodRaw: "camera",
                    mealSlotRaw: nil,
                    createdAt: Date(),
                    previewJPEG: nil
                )
            )
            onStage(.queued)
            return try await pollUntilComplete(
                baseURL: baseURL,
                analysisId: analysisId,
                bearer: bearer,
                clock: clock,
                onStage: onStage,
                initialPollMs: accept.pollAfterMs ?? 1000
            )
        }

        let errorBody = try? JSONDecoder().decode(PhotoFoodAPIErrorBody.self, from: data)
        let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
        let errorCode = (errorBody?.error ?? "").lowercased()
        // Sync fallback when async is unavailable:
        // - 404 / not_found: pre-async Render image (route missing)
        // - 503 async_not_configured: server running but ASYNC/DATA_DIR/worker stack off
        // Do not fall back on busy/queue 503 — those are capacity signals.
        let shouldFallbackSync = http.statusCode == 404
            || errorCode == "not_found"
            || (http.statusCode == 503 && errorCode.contains("async_not_configured"))
        if shouldFallbackSync {
            PhotoFoodDiagnostics.event(
                "asyncRouteMissingFallbackSync",
                clock: clock,
                detail: "status=\(http.statusCode) code=\(errorCode.isEmpty ? "-" : errorCode) host=\(baseURL.host ?? "-")"
            )
            return try await performSyncRecognize(
                baseURL: baseURL,
                imageJPEG: imageJPEG,
                note: note,
                bearer: bearer,
                access: access,
                clock: clock,
                onStage: onStage
            )
        }
        let mapped = PhotoFoodAPIMapper.mapHTTPStatus(http.statusCode, body: errorBody)
        PhotoFoodDiagnostics.event(
            "httpError",
            clock: clock,
            detail: "status=\(http.statusCode) mapped=\(String(describing: mapped)) code=\(errorBody?.error ?? errorBody?.code ?? "-") retryAfter=\(retryAfter ?? "-")"
        )
        if http.statusCode == 503 {
            PhotoFoodDiagnostics.event(
                "serverBusyRetryAfter",
                clock: clock,
                detail: "retryAfter=\(retryAfter ?? "-") — no automatic loop"
            )
        }
        throw mapped
    }

    private func applySubscriptionAccess(_ access: SubscriptionAccess, to request: inout URLRequest) {
        switch access {
        case .paidJWS(let jws):
            request.setValue(jws, forHTTPHeaderField: WeekFitPaidSubscriptionProof.httpHeaderName)
        case .freeTrial:
            request.setValue("1", forHTTPHeaderField: WeekFitPaidSubscriptionProof.freeTrialHTTPHeaderName)
        }
    }

    /// Synchronous `POST /v1/food/photo-recognize` — used when async accept route is not deployed yet.
    private func performSyncRecognize(
        baseURL: URL,
        imageJPEG: Data,
        note: String?,
        bearer: String,
        access: SubscriptionAccess,
        clock: PhotoFoodDiagnostics.AnalysisClock,
        onStage: @escaping @Sendable (PhotoFoodNetworkStage) -> Void
    ) async throws -> PhotoFoodAPIResponse {
        let url = baseURL.appending(path: "v1/food/photo-recognize")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.acceptTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        applySubscriptionAccess(access, to: &request)
        request.setValue(clock.analysisId, forHTTPHeaderField: "Idempotency-Key")

        let body = PhotoFoodRecognizeRequest(
            imageBase64: imageJPEG.base64EncodedString(),
            mimeType: "image/jpeg",
            locale: PhotoFoodRecognitionClient.recognitionLocaleIdentifier(),
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        request.httpBody = try JSONEncoder().encode(body)

        onStage(.uploading)
        PhotoFoodDiagnostics.stage("uploadSync", clock: clock)
        let uploadStarted = clock.elapsedMs
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw PhotoFoodRecognitionError.cancelled
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw PhotoFoodRecognitionError.cancelled
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw PhotoFoodRecognitionError.timedOut
        } catch {
            throw PhotoFoodRecognitionError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw PhotoFoodRecognitionError.invalidResponse
        }
        PhotoFoodDiagnostics.http(
            clock: clock,
            status: http.statusCode,
            responseBytes: data.count,
            requestId: clock.analysisId,
            durationMs: clock.elapsedMs - uploadStarted
        )

        if http.statusCode == 200 {
            onStage(.waitingForResponse)
            do {
                let decoded = try JSONDecoder().decode(PhotoFoodAPIResponse.self, from: data)
                try PhotoFoodAPIResponseValidator.validate(decoded)
                PhotoFoodDiagnostics.decodeSuccess(
                    clock: clock,
                    itemCount: decoded.items.count,
                    isFood: decoded.isFood,
                    requiresConfirmation: decoded.requiresConfirmation,
                    requestId: decoded.requestId,
                    durationMs: clock.elapsedMs - uploadStarted
                )
                PhotoFoodPendingAnalysisStore.clear(analysisId: clock.analysisId)
                return decoded
            } catch {
                PhotoFoodDiagnostics.decodeFailure(clock: clock, error: error, durationMs: clock.elapsedMs - uploadStarted)
                throw PhotoFoodRecognitionError.invalidResponse
            }
        }

        let errorBody = try? JSONDecoder().decode(PhotoFoodAPIErrorBody.self, from: data)
        let mapped = PhotoFoodAPIMapper.mapHTTPStatus(http.statusCode, body: errorBody)
        PhotoFoodDiagnostics.event(
            "httpErrorSync",
            clock: clock,
            detail: "status=\(http.statusCode) mapped=\(String(describing: mapped)) code=\(errorBody?.error ?? "-")"
        )
        throw mapped
    }

    private func pollUntilComplete(
        baseURL: URL,
        analysisId: String,
        bearer: String,
        clock: PhotoFoodDiagnostics.AnalysisClock,
        onStage: @escaping @Sendable (PhotoFoodNetworkStage) -> Void,
        initialPollMs: Int
    ) async throws -> PhotoFoodAPIResponse {
        // Authenticated long-poll (?waitMs=) — one held GET instead of chatty short polls.
        // Fallback: if long-poll errors, brief GET without waitMs then retry long-poll.
        var fallbackDelayMs = max(200, min(initialPollMs, 500))
        while true {
            try Task.checkCancellation()
            var components = URLComponents(
                url: baseURL.appending(path: "v1/food/photo-analyze/\(analysisId)"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [URLQueryItem(name: "waitMs", value: "20000")]
            guard let url = components?.url else {
                throw PhotoFoodRecognitionError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            // Must cover long-poll hold + network margin.
            request.timeoutInterval = 35
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch is CancellationError {
                throw PhotoFoodRecognitionError.cancelled
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw PhotoFoodRecognitionError.cancelled
            } catch {
                PhotoFoodDiagnostics.event("longPollNetwork", clock: clock)
                // Fallback short GET without wait.
                try await Task.sleep(for: .milliseconds(fallbackDelayMs))
                fallbackDelayMs = min(1_500, Int(Double(fallbackDelayMs) * 1.3))
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                throw PhotoFoodRecognitionError.invalidResponse
            }
            if http.statusCode != 200 {
                let errorBody = try? JSONDecoder().decode(PhotoFoodAPIErrorBody.self, from: data)
                throw PhotoFoodAPIMapper.mapHTTPStatus(http.statusCode, body: errorBody)
            }

            let status = try JSONDecoder().decode(PhotoFoodAsyncStatus.self, from: data)
            switch status.status {
            case "queued":
                onStage(.queued)
            case "processing":
                onStage(.processing)
            case "completed":
                guard let result = status.result else {
                    throw PhotoFoodRecognitionError.invalidResponse
                }
                try PhotoFoodAPIResponseValidator.validate(result)
                PhotoFoodPendingAnalysisStore.clear(analysisId: analysisId)
                PhotoFoodDiagnostics.decodeSuccess(
                    clock: clock,
                    itemCount: result.items.count,
                    isFood: result.isFood,
                    requiresConfirmation: result.requiresConfirmation,
                    requestId: result.requestId ?? analysisId,
                    durationMs: clock.elapsedMs
                )
                return result
            case "failed":
                PhotoFoodPendingAnalysisStore.clear(analysisId: analysisId)
                let code = (status.error ?? "").lowercased()
                if code.contains("no_food") {
                    throw PhotoFoodRecognitionError.noFoodDetected
                }
                if code.contains("timeout") || code.contains("queue_wait") {
                    throw PhotoFoodRecognitionError.timedOut
                }
                if code.contains("busy") || code.contains("circuit") || code.contains("rpm") || code.contains("tpm") {
                    throw PhotoFoodRecognitionError.unavailable
                }
                throw PhotoFoodRecognitionError.providerFailure
            default:
                onStage(.waitingForResponse)
            }
            // Still in flight after wait window — immediately long-poll again (no artificial gap).
        }
    }
}

private struct PhotoFoodAsyncAccept: Decodable {
    let analysisId: String
    let status: String
    let pollAfterMs: Int?
    let result: PhotoFoodAPIResponse?
    let error: String?
}

private struct PhotoFoodAsyncStatus: Decodable {
    let analysisId: String
    let status: String
    let result: PhotoFoodAPIResponse?
    let error: String?
    let pollAfterMs: Int?
}

/// Sanitized peek — only `requestId`, never response body contents.
private struct PhotoFoodRequestIdPeek: Decodable {
    let requestId: String?
}

enum PhotoFoodAPIResponseValidator {
    static func validate(_ response: PhotoFoodAPIResponse) throws {
        guard response.isFood else {
            throw PhotoFoodRecognitionError.noFoodDetected
        }
        guard response.requiresConfirmation else {
            throw PhotoFoodRecognitionError.invalidResponse
        }
        let name = response.name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Backend allows up to 200; keep client in sync so valid 200s are not dropped.
        guard !name.isEmpty, name.count <= 200 else {
            throw PhotoFoodRecognitionError.invalidResponse
        }
        guard !response.items.isEmpty, response.items.count <= 30 else {
            throw PhotoFoodRecognitionError.invalidResponse
        }
        for item in response.items {
            let itemName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !itemName.isEmpty else {
                throw PhotoFoodRecognitionError.invalidResponse
            }
            guard item.grams.isFinite, item.grams > 0, item.grams <= 5000 else {
                throw PhotoFoodRecognitionError.invalidResponse
            }
        }
    }
}

#if DEBUG
/// Deterministic fixture — only when `WeekFitUsePhotoFoodFixture` is explicitly enabled.
struct PhotoFoodRecognitionFixtureClient: PhotoFoodRecognizing {
    var payload: PhotoFoodAPIResponse = .fixturePlate

    func recognizeFood(
        imageJPEG: Data,
        note: String?,
        analysisId: String,
        onStage: @escaping @Sendable (PhotoFoodNetworkStage) -> Void
    ) async throws -> PhotoFoodAPIResponse {
        _ = imageJPEG
        _ = note
        _ = analysisId
        onStage(.authenticating)
        onStage(.uploading)
        onStage(.waitingForResponse)
        try await Task.sleep(nanoseconds: 200_000_000)
        try PhotoFoodAPIResponseValidator.validate(payload)
        return payload
    }
}
#endif

extension PhotoFoodAPIResponse {
    static var fixturePlate: PhotoFoodAPIResponse {
        PhotoFoodAPIResponse(
            isFood: true,
            name: "Chicken rice bowl",
            items: [
                .init(
                    name: "Cooked rice",
                    preparation: "cooked",
                    grams: 180,
                    minGrams: 140,
                    maxGrams: 220,
                    calories: 234,
                    protein: 4.9,
                    carbs: 50.4,
                    fat: 0.5,
                    assumptions: ["Cooked weight estimated from plate."]
                ),
                .init(
                    name: "Chicken breast",
                    preparation: "grilled",
                    grams: 120,
                    minGrams: 90,
                    maxGrams: 150,
                    calories: 198,
                    protein: 37,
                    carbs: 0,
                    fat: 4.3,
                    assumptions: []
                )
            ],
            uncertainties: ["Portion weight cannot be measured from this photo"],
            clarificationQuestion: "Was oil or sauce added?",
            totals: .init(grams: 300, calories: 432, protein: 41.9, carbs: 50.4, fat: 4.8),
            nutritionSource: "ai_estimate",
            estimated: true,
            requiresConfirmation: true,
            model: "fixture",
            requestId: "fixture-local"
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
