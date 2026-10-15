import XCTest
import UIKit
@testable import WeekFit

@MainActor
final class PhotoFoodLogCoordinatorTests: XCTestCase {

    func testSuccessfulRecognitionLeavesAnalyzingAndShowsConfirmation() async throws {
        let client = StubRecognitionClient(result: .success(.fixturePlate))
        let coordinator = makeCoordinator(client: client)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        try await waitUntil(coordinator, leaves: .analyzing, timeout: 2)

        guard case .confirmation = coordinator.phase else {
            return XCTFail("Expected confirmation, got \(coordinator.phase)")
        }
        XCTAssertEqual(coordinator.draft?.mealName, "Chicken rice bowl")
        XCTAssertEqual(coordinator.draft?.components.count, 2)
    }

    func testCancelledRecognitionExitsLoading() async throws {
        let client = StubRecognitionClient(result: .failure(.cancelled))
        let coordinator = makeCoordinator(client: client)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        try await waitUntil(coordinator, leaves: .analyzing, timeout: 2)

        guard case .error(let error) = coordinator.phase else {
            return XCTFail("Expected error, got \(coordinator.phase)")
        }
        XCTAssertEqual(error, .cancelled)
        XCTAssertNotNil(coordinator.lastImage)
    }

    func testUserCancelExitsWaitingAndKeepsPhoto() async throws {
        let gate = AsyncGate()
        let client = StubRecognitionClient(result: .success(.fixturePlate), gate: gate)
        let coordinator = makeCoordinator(client: client)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        XCTAssertEqual(coordinator.phase, .analyzing)
        coordinator.cancelAnalysis()

        guard case .error(let error) = coordinator.phase else {
            return XCTFail("Expected cancelled error, got \(coordinator.phase)")
        }
        XCTAssertEqual(error, .cancelled)
        XCTAssertNotNil(coordinator.lastImage)

        await gate.open()
        try await Task.sleep(nanoseconds: 50_000_000)
        guard case .error = coordinator.phase else {
            return XCTFail("Late success must not open confirmation after cancel")
        }
    }

    func testLateSuccessAfterResetDoesNotOpenConfirmation() async throws {
        let gate = AsyncGate()
        let client = StubRecognitionClient(result: .success(.fixturePlate), gate: gate)
        let coordinator = makeCoordinator(client: client)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        XCTAssertEqual(coordinator.phase, .analyzing)
        coordinator.reset()
        XCTAssertEqual(coordinator.phase, .idle)
        await gate.open()

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertNil(coordinator.draft)
    }

    func testDecodeFailureSurfacesInvalidResponse() async throws {
        let client = StubRecognitionClient(result: .failure(.invalidResponse))
        let coordinator = makeCoordinator(client: client)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .library)
        try await waitUntil(coordinator, leaves: .analyzing, timeout: 2)

        guard case .error(let error) = coordinator.phase else {
            return XCTFail("Expected error, got \(coordinator.phase)")
        }
        XCTAssertEqual(error, .invalidResponse)
        XCTAssertNotNil(coordinator.lastImage)
    }

    func testTimedOutExitsLoading() async throws {
        let client = StubRecognitionClient(result: .failure(.timedOut))
        let coordinator = makeCoordinator(client: client)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        try await waitUntil(coordinator, leaves: .analyzing, timeout: 2)

        guard case .error(let error) = coordinator.phase else {
            return XCTFail("Expected timeout error, got \(coordinator.phase)")
        }
        XCTAssertEqual(error, .timedOut)
    }

    func testBlocksSecondLaunchWhileInFlight() async throws {
        let gate = AsyncGate()
        let client = StubRecognitionClient(result: .success(.fixturePlate), gate: gate)
        let coordinator = makeCoordinator(client: client)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        let firstId = coordinator.lastAnalysisId
        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .library)
        XCTAssertEqual(coordinator.lastAnalysisId, firstId)
        XCTAssertEqual(coordinator.phase, .analyzing)

        await gate.open()
        try await waitUntil(coordinator, leaves: .analyzing, timeout: 2)
        guard case .confirmation = coordinator.phase else {
            return XCTFail("Expected confirmation, got \(coordinator.phase)")
        }
    }

    func testProgressReachesWaitingStage() async throws {
        let gate = AsyncGate()
        let client = StubRecognitionClient(result: .success(.fixturePlate), gate: gate)
        let coordinator = makeCoordinator(client: client)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        let deadline = Date().addingTimeInterval(2)
        while coordinator.progress != .waiting, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(coordinator.progress, .waiting)
        await gate.open()
        try await waitUntil(coordinator, leaves: .analyzing, timeout: 2)
    }

    private func makeCoordinator(
        client: StubRecognitionClient,
        canUseCloud: Bool = true
    ) -> PhotoFoodLogCoordinator {
        PhotoFoodLogCoordinator(
            mealSlot: .lunch,
            logDate: Date(),
            recognitionClient: client,
            localAnalyzer: { _ in .failure(.noContent) },
            canUseCloudPhotoNutritionAnalysis: { canUseCloud }
        )
    }

    func testCloudAnalysisBlockedWithoutPaidSubscription() async throws {
        let client = StubRecognitionClient(result: .success(.fixturePlate))
        let coordinator = makeCoordinator(client: client, canUseCloud: false)

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        try await waitUntil(coordinator, leaves: .analyzing, timeout: 2)

        guard case .error(let error) = coordinator.phase else {
            return XCTFail("Expected subscriptionRequired, got \(coordinator.phase)")
        }
        XCTAssertEqual(error, .subscriptionRequired)
        XCTAssertNotNil(coordinator.lastImage)
        XCTAssertEqual(client.recognizeCallCount, 0)
    }

    func testLocalNutritionLabelSkipsPaidSubscriptionGate() async throws {
        let client = StubRecognitionClient(result: .success(.fixturePlate))
        let estimate = FoodPhotoNutritionEstimate(
            source: .nutritionLabel,
            dataSource: .nutritionLabelOCR,
            barcode: nil,
            name: "Label yogurt",
            calories: 120,
            protein: 10,
            carbs: 12,
            fats: 3,
            fiber: 0,
            servingGrams: 150,
            packageGrams: nil,
            productImageURL: nil
        )
        let coordinator = PhotoFoodLogCoordinator(
            mealSlot: .lunch,
            logDate: Date(),
            recognitionClient: client,
            localAnalyzer: { _ in .nutritionLabel(estimate) },
            canUseCloudPhotoNutritionAnalysis: { false }
        )

        coordinator.analyzePhoto(UIImage.photoFoodSolidTestImage, method: .camera)
        try await waitUntil(coordinator, leaves: .analyzing, timeout: 2)

        guard case .confirmation = coordinator.phase else {
            return XCTFail("Expected confirmation for label, got \(coordinator.phase)")
        }
        XCTAssertEqual(client.recognizeCallCount, 0)
        XCTAssertEqual(coordinator.draft?.mealName, "Label yogurt")
    }

    private func waitUntil(
        _ coordinator: PhotoFoodLogCoordinator,
        leaves phase: PhotoFoodLogCoordinator.Phase,
        timeout: TimeInterval
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while coordinator.phase == phase, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class StubRecognitionClient: PhotoFoodRecognizing, @unchecked Sendable {
    enum Result {
        case success(PhotoFoodAPIResponse)
        case failure(PhotoFoodRecognitionError)
    }

    let result: Result
    var gate: AsyncGate?
    private(set) var recognizeCallCount = 0

    init(result: Result, gate: AsyncGate? = nil) {
        self.result = result
        self.gate = gate
    }

    func recognizeFood(
        imageJPEG: Data,
        note: String?,
        analysisId: String,
        onStage: @escaping @Sendable (PhotoFoodNetworkStage) -> Void
    ) async throws -> PhotoFoodAPIResponse {
        _ = imageJPEG
        _ = note
        _ = analysisId
        recognizeCallCount += 1
        onStage(.authenticating)
        onStage(.uploading)
        onStage(.waitingForResponse)
        if let gate {
            await gate.wait()
        }
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

private extension UIImage {
    static var photoFoodSolidTestImage: UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        return renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }
}
