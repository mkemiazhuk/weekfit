import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class PhotoFoodLogCoordinator {
    enum Phase: Equatable {
        case idle
        case analyzing
        case confirmation
        case logging
        case error(PhotoFoodRecognitionError)
    }

    var phase: Phase = .idle
    var draft: PhotoFoodLogDraft?
    var progress: PhotoFoodAnalysisProgress = .preparing
    private(set) var lastImage: UIImage?
    private(set) var lastCaptureMethod: PhotoFoodCaptureMethod = .camera
    private(set) var lastAnalysisId: String?

    var mealSlot: WeekFitMealSlot
    var logDate: Date

    var isAnalysisInFlight: Bool { phase == .analyzing }

    private let recognitionClient: any PhotoFoodRecognizing
    /// Injected for tests so Vision / barcode work can be skipped.
    private let localAnalyzer: (UIImage) async -> FoodPhotoAnalysisResult
    /// Paid subscription only — trial / legacy / free promo must return false.
    private let canUseCloudPhotoNutritionAnalysis: () -> Bool
    private var analysisTask: Task<Void, Never>?
    private var longWaitTask: Task<Void, Never>?
    private var analysisGeneration: UInt = 0
    private var activeClock: PhotoFoodDiagnostics.AnalysisClock?

    init(
        mealSlot: WeekFitMealSlot,
        logDate: Date,
        recognitionClient: (any PhotoFoodRecognizing)? = nil,
        localAnalyzer: ((UIImage) async -> FoodPhotoAnalysisResult)? = nil,
        canUseCloudPhotoNutritionAnalysis: @escaping () -> Bool = { false }
    ) {
        self.mealSlot = mealSlot
        self.logDate = logDate
        self.canUseCloudPhotoNutritionAnalysis = canUseCloudPhotoNutritionAnalysis
        self.localAnalyzer = localAnalyzer ?? { image in
            await FoodPhotoNutritionAnalyzer.analyze(image)
        }
        if let recognitionClient {
            self.recognitionClient = recognitionClient
        } else {
            #if DEBUG
            if WeekFitCloudAPI.usePhotoFoodFixture {
                self.recognitionClient = PhotoFoodRecognitionFixtureClient()
            } else {
                self.recognitionClient = PhotoFoodRecognitionClient()
            }
            #else
            self.recognitionClient = PhotoFoodRecognitionClient()
            #endif
        }
    }

    func reset() {
        let previous = phaseLabel
        invalidateInFlightWork(reason: "reset")
        phase = .idle
        draft = nil
        lastImage = nil
        progress = .preparing
        if let clock = activeClock {
            PhotoFoodDiagnostics.stateTransition(clock: clock, from: previous, to: "idle")
        }
        activeClock = nil
        lastAnalysisId = nil
    }

    /// Cancels the in-flight request, keeps the photo, and exits waiting immediately.
    func cancelAnalysis() {
        guard phase == .analyzing else { return }
        let previous = phaseLabel
        let clock = activeClock
        invalidateInFlightWork(reason: "userCancel")
        phase = .error(.cancelled)
        progress = .preparing
        if let clock {
            PhotoFoodDiagnostics.cancelled(clock: clock, at: "userCancel")
            PhotoFoodDiagnostics.stateTransition(clock: clock, from: previous, to: "error.cancelled")
        }
        // Keep lastImage for Retry / Manual.
    }

    func analyzePhoto(
        _ image: UIImage,
        method: PhotoFoodCaptureMethod,
        reuseAnalysisId: String? = nil
    ) {
        // Block duplicate paid launches while a request is already running.
        if phase == .analyzing {
            PhotoFoodDiagnostics.skippedApply(
                clock: activeClock,
                reason: "blockedWhileInFlight"
            )
            return
        }

        analysisTask?.cancel()
        longWaitTask?.cancel()
        analysisGeneration &+= 1
        let generation = analysisGeneration
        // Retries keep the same analysis ID so the server can return a cached result
        // (or coalesce) without a second AI call. Never auto-retry on 503.
        let clock = reuseAnalysisId.map { PhotoFoodDiagnostics.AnalysisClock(analysisId: $0) }
            ?? PhotoFoodDiagnostics.AnalysisClock()
        activeClock = clock
        lastAnalysisId = clock.analysisId
        lastImage = image
        lastCaptureMethod = method
        draft = nil
        progress = .preparing
        let previous = phaseLabel
        phase = .analyzing
        PhotoFoodDiagnostics.stateTransition(clock: clock, from: previous, to: "analyzing")
        PhotoFoodDiagnostics.event(
            "analyzeStart",
            clock: clock,
            detail: "gen=\(generation) method=\(method.rawValue) analysisId=\(clock.analysisId) reuse=\(reuseAnalysisId != nil)"
        )
        PhotoFoodAnalytics.scanStarted(method: method)
        PhotoFoodPendingAnalysisStore.save(
            PhotoFoodPendingAnalysis(
                analysisId: clock.analysisId,
                captureMethodRaw: method.rawValue,
                mealSlotRaw: mealSlot.rawValue,
                createdAt: Date(),
                previewJPEG: PhotoFoodImagePreparer.previewThumbnail(from: image)
                    .jpegData(compressionQuality: 0.7)
            )
        )

        analysisTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runAnalysis(image: image, method: method, generation: generation, clock: clock)
        }
    }

    func retryAnalysis() {
        guard let image = lastImage else { return }
        guard phase != .analyzing else { return }
        let preservedName = draft?.mealName
        let preservedMultiplier = draft?.portionMultiplier
        let preservedSave = draft?.saveToLibrary ?? false
        let preservedAnswer = draft?.clarificationAnswer ?? ""
        analyzePhoto(
            image,
            method: lastCaptureMethod,
            reuseAnalysisId: lastAnalysisId
        )
        pendingRetryMealName = preservedName
        pendingRetryMultiplier = preservedMultiplier
        pendingRetrySave = preservedSave
        pendingRetryAnswer = preservedAnswer
    }

    private var pendingRetryMealName: String?
    private var pendingRetryMultiplier: Double?
    private var pendingRetrySave: Bool?
    private var pendingRetryAnswer: String?

    func startManualFallback() {
        let component = PhotoFoodComponent(
            id: "manual_1",
            displayName: WeekFitLocalizedString("today.photoLog.unnamedFood"),
            grams: 200,
            catalogIngredientId: nil,
            preparation: nil,
            caloriesPer100g: 0,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatsPer100g: 0,
            fiberPer100g: 0,
            nutritionSource: .manual,
            isAIEstimated: true
        )
        let preview = lastImage.map { PhotoFoodImagePreparer.previewThumbnail(from: $0) }
        draft = PhotoFoodLogDraft(
            mealName: "",
            mealSlot: mealSlot,
            logDate: logDate,
            components: [component],
            captureMethod: lastCaptureMethod,
            previewImage: preview,
            showsEstimatedNutrition: true
        )
        let previous = phaseLabel
        phase = .confirmation
        if let clock = activeClock {
            PhotoFoodDiagnostics.stateTransition(clock: clock, from: previous, to: "confirmation.manual")
        }
        PhotoFoodAnalytics.confirmationShown(method: lastCaptureMethod)
    }

    // MARK: - Pipeline

    private func runAnalysis(
        image: UIImage,
        method: PhotoFoodCaptureMethod,
        generation: UInt,
        clock: PhotoFoodDiagnostics.AnalysisClock
    ) async {
        progress = .preparing
        let local = await localAnalyzer(image)
        guard isCurrentAnalysis(generation), phase == .analyzing else {
            PhotoFoodDiagnostics.cancelled(clock: clock, at: "afterLocalAnalyze")
            return
        }

        switch local {
        case .barcode(let estimate, _):
            applyBarcodeOrLabel(estimate, method: .barcode, image: image, generation: generation, clock: clock)
            return
        case .nutritionLabel(let estimate):
            applyBarcodeOrLabel(estimate, method: method, image: image, generation: generation, clock: clock)
            return
        case .failure:
            break
        }

        guard canUseCloudPhotoNutritionAnalysis() else {
            PhotoFoodDiagnostics.event(
                "subscriptionRequired",
                clock: clock,
                detail: "blockedBeforeCloud"
            )
            finishWithError(.subscriptionRequired, method: method, generation: generation, clock: clock)
            return
        }

        await runCloudRecognition(image: image, method: method, generation: generation, clock: clock)
    }

    private func applyBarcodeOrLabel(
        _ estimate: FoodPhotoNutritionEstimate,
        method: PhotoFoodCaptureMethod,
        image: UIImage,
        generation: UInt,
        clock: PhotoFoodDiagnostics.AnalysisClock
    ) {
        guard isCurrentAnalysis(generation), phase == .analyzing else {
            PhotoFoodDiagnostics.skippedApply(clock: clock, reason: "barcode staleOrDismissed")
            return
        }
        let component = PhotoFoodCatalogMatcher.component(from: estimate)
        let name = estimate.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? WeekFitLocalizedString("today.photoLog.unnamedFood")
        let draft = PhotoFoodLogDraft(
            mealName: name,
            mealSlot: mealSlot,
            logDate: logDate,
            components: [component],
            captureMethod: method,
            previewImage: PhotoFoodImagePreparer.previewThumbnail(from: image),
            barcode: estimate.barcode,
            barcodeDataSource: estimate.dataSource,
            showsEstimatedNutrition: false
        )
        applyPendingRetry(to: draft)
        self.draft = draft
        let previous = phaseLabel
        phase = .confirmation
        PhotoFoodDiagnostics.stateTransition(clock: clock, from: previous, to: "confirmation")
        PhotoFoodDiagnostics.event("confirmation", clock: clock, detail: "components=1 source=local")
        PhotoFoodAnalytics.scanCompleted(method: method)
        PhotoFoodAnalytics.confirmationShown(method: method)
    }

    private func runCloudRecognition(
        image: UIImage,
        method: PhotoFoodCaptureMethod,
        generation: UInt,
        clock: PhotoFoodDiagnostics.AnalysisClock
    ) async {
        guard isCurrentAnalysis(generation), phase == .analyzing else {
            PhotoFoodDiagnostics.skippedApply(clock: clock, reason: "cloud entry staleOrDismissed")
            return
        }

        progress = .preparing
        let prepareStarted = clock.elapsedMs
        let jpeg = PhotoFoodImagePreparer.prepareUploadJPEG(from: image)
        PhotoFoodDiagnostics.stage(
            "prepare",
            clock: clock,
            durationMs: clock.elapsedMs - prepareStarted
        )

        guard isCurrentAnalysis(generation), phase == .analyzing else {
            PhotoFoodDiagnostics.cancelled(clock: clock, at: "afterPrepare")
            return
        }
        guard let jpeg else {
            finishWithError(.invalidImage, method: method, generation: generation, clock: clock)
            return
        }

        do {
            let response = try await recognitionClient.recognizeFood(
                imageJPEG: jpeg,
                note: nil,
                analysisId: clock.analysisId,
                onStage: { [weak self] stage in
                    Task { @MainActor in
                        self?.applyNetworkStage(stage, generation: generation, clock: clock)
                    }
                }
            )
            // Apply only if this analysis is still the active waiting one.
            guard isCurrentAnalysis(generation), phase == .analyzing else {
                PhotoFoodDiagnostics.skippedApply(
                    clock: clock,
                    reason: "cloud success after dismiss/cancel requestId=\(response.requestId ?? "-")"
                )
                return
            }
            let components = try PhotoFoodAPIMapper.components(from: response)
            let assumptions = response.items.flatMap { $0.assumptions ?? [] }
            let draft = PhotoFoodLogDraft(
                mealName: response.name,
                mealSlot: mealSlot,
                logDate: logDate,
                components: components,
                clarificationQuestion: Self.sanitizedClarification(response.clarificationQuestion),
                assumptions: assumptions,
                uncertainties: response.uncertainties,
                captureMethod: method,
                previewImage: PhotoFoodImagePreparer.previewThumbnail(from: image),
                showsEstimatedNutrition: true
            )
            applyPendingRetry(to: draft)
            self.draft = draft
            longWaitTask?.cancel()
            let previous = phaseLabel
            phase = .confirmation
            PhotoFoodDiagnostics.stateTransition(clock: clock, from: previous, to: "confirmation")
            PhotoFoodDiagnostics.event(
                "confirmation",
                clock: clock,
                detail: "components=\(components.count) requestId=\(response.requestId ?? "-")"
            )
            PhotoFoodPendingAnalysisStore.clear(analysisId: clock.analysisId)
            PhotoFoodAnalytics.scanCompleted(method: method)
            PhotoFoodAnalytics.confirmationShown(method: method)
        } catch let error as PhotoFoodRecognitionError {
            if error == .cancelled {
                PhotoFoodDiagnostics.cancelled(clock: clock, at: "cloudRecognition")
                finishWithError(.cancelled, method: method, generation: generation, clock: clock, analytics: false)
                return
            }
            // Keep pending record on overload/timeout so Retry / reopen can resume same ID.
            if error != .unavailable && error != .timedOut && error != .network {
                PhotoFoodPendingAnalysisStore.clear(analysisId: clock.analysisId)
            }
            finishWithError(error, method: method, generation: generation, clock: clock)
        } catch is CancellationError {
            PhotoFoodDiagnostics.cancelled(clock: clock, at: "cloudRecognition.CancellationError")
            finishWithError(.cancelled, method: method, generation: generation, clock: clock, analytics: false)
        } catch {
            finishWithError(.invalidResponse, method: method, generation: generation, clock: clock)
        }
    }

    private func applyNetworkStage(
        _ stage: PhotoFoodNetworkStage,
        generation: UInt,
        clock: PhotoFoodDiagnostics.AnalysisClock
    ) {
        guard isCurrentAnalysis(generation), phase == .analyzing else { return }
        switch stage {
        case .authenticating:
            longWaitTask?.cancel()
            progress = .authenticating
        case .uploading:
            longWaitTask?.cancel()
            progress = .uploading
        case .queued:
            longWaitTask?.cancel()
            progress = .queued
            startLongWaitTimer(generation: generation, clock: clock)
        case .processing:
            longWaitTask?.cancel()
            progress = .processing
            startLongWaitTimer(generation: generation, clock: clock)
        case .waitingForResponse:
            if progress != .waitingLong {
                progress = .waiting
            }
            startLongWaitTimer(generation: generation, clock: clock)
        }
    }

    private func startLongWaitTimer(
        generation: UInt,
        clock: PhotoFoodDiagnostics.AnalysisClock
    ) {
        longWaitTask?.cancel()
        longWaitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard let self, !Task.isCancelled else { return }
            guard self.isCurrentAnalysis(generation), self.phase == .analyzing else { return }
            guard self.progress == .waiting
                || self.progress == .waitingLong
                || self.progress == .queued
                || self.progress == .processing
            else { return }
            self.progress = .waitingLong
            PhotoFoodDiagnostics.event("waitingLong", clock: clock)
        }
    }

    private func finishWithError(
        _ error: PhotoFoodRecognitionError,
        method: PhotoFoodCaptureMethod,
        generation: UInt,
        clock: PhotoFoodDiagnostics.AnalysisClock,
        analytics: Bool = true
    ) {
        guard isCurrentAnalysis(generation), phase == .analyzing else {
            PhotoFoodDiagnostics.skippedApply(
                clock: clock,
                reason: "error staleOrDismissed \(String(describing: error))"
            )
            return
        }
        longWaitTask?.cancel()
        let previous = phaseLabel
        phase = .error(error)
        // Keep lastImage + any draft context for Retry / Manual.
        PhotoFoodDiagnostics.stateTransition(
            clock: clock,
            from: previous,
            to: "error.\(String(describing: error))"
        )
        if analytics {
            PhotoFoodAnalytics.scanFailed(
                method: method,
                reason: Self.analyticsReason(for: error)
            )
        }
    }

    private func invalidateInFlightWork(reason: String) {
        analysisGeneration &+= 1
        analysisTask?.cancel()
        analysisTask = nil
        longWaitTask?.cancel()
        longWaitTask = nil
        if let clock = activeClock {
            PhotoFoodDiagnostics.event("invalidate", clock: clock, detail: reason)
        }
    }

    private func isCurrentAnalysis(_ generation: UInt) -> Bool {
        generation == analysisGeneration
    }

    private var phaseLabel: String {
        switch phase {
        case .idle: return "idle"
        case .analyzing: return "analyzing"
        case .confirmation: return "confirmation"
        case .logging: return "logging"
        case .error(let error): return "error.\(String(describing: error))"
        }
    }

    private func applyPendingRetry(to draft: PhotoFoodLogDraft) {
        if let name = pendingRetryMealName, !name.isEmpty {
            draft.mealName = name
        }
        if let multiplier = pendingRetryMultiplier {
            draft.portionMultiplier = multiplier
        }
        if let save = pendingRetrySave {
            draft.saveToLibrary = save
        }
        if let answer = pendingRetryAnswer {
            draft.clarificationAnswer = answer
        }
        pendingRetryMealName = nil
        pendingRetryMultiplier = nil
        pendingRetrySave = nil
        pendingRetryAnswer = nil
    }

    private static func sanitizedClarification(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8, trimmed.count <= 120 else { return nil }
        return trimmed
    }

    private static func analyticsReason(for error: PhotoFoodRecognitionError) -> SafeAnalyticsFailureReason {
        switch error {
        case .network, .timedOut, .unavailable, .providerFailure:
            return .lookupFailed
        case .unauthorized, .notConfigured, .authUnavailable, .subscriptionRequired:
            return .unavailable
        default:
            return .invalidInput
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
