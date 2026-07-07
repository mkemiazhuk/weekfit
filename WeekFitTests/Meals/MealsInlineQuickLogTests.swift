import XCTest
@testable import WeekFit

@MainActor
final class MealsInlineQuickLogTests: XCTestCase {

    private func sampleMealProfile() -> QuickLogNutritionProfile {
        QuickLogNutritionProfile.from(
            meal: Meals(
                id: "meal_inline",
                title: "Turkey Rice",
                subtitle: "Balanced bowl",
                imageName: "meal-turkey",
                type: .highProtein,
                calories: 480,
                protein: 36,
                carbs: 42,
                fats: 14,
                benefits: [],
                ingredients: [],
                servingGrams: 320
            )
        )
    }

    func testQuickAddExpandsInlineStepperSelection() {
        let session = QuickLogSessionStore()
        let profile = sampleMealProfile()

        let selection = session.quickAdd(profile: profile)

        XCTAssertTrue(selection.isExpanded)
        XCTAssertTrue(selection.isSelected)
        XCTAssertEqual(selection.portions, 1)
        XCTAssertEqual(session.selection(for: profile.id).isExpanded, true)
    }

    func testIncrementUpdatesPortionsForInlineStepper() {
        let session = QuickLogSessionStore()
        let profile = sampleMealProfile()

        _ = session.quickAdd(profile: profile)
        session.increment(profile: profile)

        XCTAssertEqual(session.selection(for: profile.id).portions, 2)
    }

    func testAutoDismissCallbackFiresForInlineFlow() {
        let session = QuickLogSessionStore()
        let profile = sampleMealProfile()
        let expectation = expectation(description: "auto dismiss")

        session.onSheetDismissRequest = { itemID in
            XCTAssertEqual(itemID, profile.id)
            expectation.fulfill()
        }

        _ = session.quickAdd(profile: profile)

        wait(for: [expectation], timeout: 2.0)
    }

    func testLibraryRevisionChangesAfterCustomMealsLoad() {
        let viewModel = MealsViewModel()
        let before = libraryRevision(for: viewModel)

        viewModel.applyLoadedCustomMeals([
            Meals(
                id: "meal_loaded",
                title: "Loaded Meal",
                subtitle: "",
                imageName: "",
                type: .highProtein,
                calories: 400,
                protein: 30,
                carbs: 20,
                fats: 10,
                benefits: [],
                ingredients: []
            )
        ])

        let after = libraryRevision(for: viewModel)
        XCTAssertNotEqual(before, after)
    }

    func testReleaseMemoryCacheDoesNotCrash() {
        MealPhotoStore.releaseMemoryCache()
    }

    func testDownsampledImageFromDataCapsPixelSize() throws {
        let size = CGSize(width: 3200, height: 2400)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let large = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let data = large.jpegData(compressionQuality: 0.92) else {
            XCTFail("Expected JPEG data")
            return
        }

        guard let downsampled = MealPhotoStore.downsampledImage(from: data) else {
            XCTFail("Expected downsampled image")
            return
        }

        XCTAssertLessThanOrEqual(max(downsampled.size.width, downsampled.size.height), MealPhotoStore.originalMaxPixelSize)
    }

    func testPromotePendingOriginalCreatesPhotoSet() throws {
        let size = CGSize(width: 120, height: 90)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let pending = try MealPhotoStore.savePendingOriginal(image)
        let photoSet = try MealPhotoStore.promotePendingOriginal(pending)

        XCTAssertTrue(photoSet.originalFilename.hasPrefix("original-"))
        XCTAssertTrue(photoSet.thumbnailFilename.hasPrefix("thumb-"))
        XCTAssertNotNil(MealPhotoStore.url(for: photoSet.originalFilename))
        XCTAssertNotNil(MealPhotoStore.url(for: photoSet.thumbnailFilename))

        MealPhotoStore.deletePhotoSet(
            originalFilename: photoSet.originalFilename,
            thumbnailFilename: photoSet.thumbnailFilename
        )
    }

    private func libraryRevision(for viewModel: MealsViewModel) -> String {
        "\(viewModel.hasLoadedCustomMeals)-\(viewModel.customMeals.count)-\(viewModel.lastRecommendationSignature)"
    }
}
