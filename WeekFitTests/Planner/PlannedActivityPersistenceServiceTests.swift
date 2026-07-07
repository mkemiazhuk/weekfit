import SwiftData
import XCTest
@testable import WeekFit

@MainActor
final class PlannedActivityPersistenceServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        PlannedActivityPersistenceService.onSaveForTesting = nil
        PlannedActivityPersistenceService.notificationCleanupHandler = nil
    }

    override func tearDownWithError() throws {
        PlannedActivityPersistenceService.onSaveForTesting = nil
        PlannedActivityPersistenceService.notificationCleanupHandler = nil
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testSingleDrinkDeletePersistsAfterRefetch() throws {
        let drink = makeDrink(title: "Coffee")
        context.insert(drink)
        try context.save()

        _ = try PlannedActivityPersistenceService.deleteActivities(
            [drink],
            modelContext: context,
            auditSource: "test.singleDrink"
        )

        let refetched = try fetchAllActivities()
        XCTAssertTrue(refetched.isEmpty)
        XCTAssertEqual(try remainingCount(for: drink.id), 0)
    }

    func testWaterGroupDeletePersistsAfterRefetch() throws {
        let drinks = [
            makeWaterLog(milliliters: 250, offsetMinutes: 0),
            makeWaterLog(milliliters: 250, offsetMinutes: 1),
            makeWaterLog(milliliters: 500, offsetMinutes: 2)
        ]
        drinks.forEach { context.insert($0) }
        try context.save()

        _ = try PlannedActivityPersistenceService.deleteActivities(
            drinks,
            modelContext: context,
            auditSource: "test.waterGroup"
        )

        let refetched = try fetchAllActivities()
        XCTAssertTrue(refetched.isEmpty)
        for drink in drinks {
            XCTAssertEqual(try remainingCount(for: drink.id), 0)
        }
    }

    func testNotificationCleanupDelayDoesNotPreventDeletion() throws {
        let drink = makeDrink(title: "Tea")
        context.insert(drink)
        try context.save()

        PlannedActivityPersistenceService.notificationCleanupHandler = { _ in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }

        _ = try PlannedActivityPersistenceService.deleteActivities(
            [drink],
            modelContext: context,
            auditSource: "test.notificationDelay"
        )

        XCTAssertEqual(try remainingCount(for: drink.id), 0)
        XCTAssertTrue(try fetchAllActivities().isEmpty)
    }

    func testWaterGroupDeleteUsesSingleSave() throws {
        let drinks = [
            makeWaterLog(milliliters: 250, offsetMinutes: 0),
            makeWaterLog(milliliters: 250, offsetMinutes: 1)
        ]
        drinks.forEach { context.insert($0) }
        try context.save()

        var saveCount = 0
        PlannedActivityPersistenceService.onSaveForTesting = {
            saveCount += 1
        }

        _ = try PlannedActivityPersistenceService.deleteActivities(
            drinks,
            modelContext: context,
            auditSource: "test.singleSave"
        )

        XCTAssertEqual(saveCount, 1)
    }

    func testPlanViewModelRemovePlannedActivitiesUsesPersistenceService() throws {
        let viewModel = PlanViewModel()
        let drink = makeDrink(title: "Protein Shake")
        context.insert(drink)
        try context.save()

        viewModel.removePlannedActivities(withIDs: [drink.id], modelContext: context)

        XCTAssertEqual(try remainingCount(for: drink.id), 0)
    }

    func testDeleteActivitiesFetchesLiveObjectByIDBeforeDelete() throws {
        let drink = makeDrink(title: "Espresso")
        context.insert(drink)
        try context.save()

        let detachedCopy = drink

        _ = try PlannedActivityPersistenceService.deleteActivities(
            withIDs: [detachedCopy.id],
            modelContext: context,
            auditSource: "test.fetchByID"
        )

        XCTAssertTrue(try fetchAllActivities().isEmpty)
    }

    private func fetchAllActivities() throws -> [PlannedActivity] {
        try context.fetch(FetchDescriptor<PlannedActivity>())
    }

    private func remainingCount(for activityID: String) throws -> Int {
        try PlannedActivityPersistenceService.remainingCount(for: activityID, in: context)
    }

    private func makeDrink(title: String) -> PlannedActivity {
        PlannedActivity(
            date: Date(),
            type: "drink",
            title: title,
            durationMinutes: 25,
            icon: "cup.and.saucer.fill",
            imageName: "ingredient-coffee",
            colorRed: 0.25,
            colorGreen: 0.55,
            colorBlue: 0.95,
            isCompleted: true,
            isSkipped: false,
            source: "today"
        )
    }

    private func makeWaterLog(milliliters: Int, offsetMinutes: Int) -> PlannedActivity {
        PlannedActivity(
            date: Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: Date()) ?? Date(),
            type: "drink",
            title: "Water",
            durationMinutes: milliliters,
            icon: "drop.fill",
            imageName: "hydration",
            colorRed: 0.25,
            colorGreen: 0.55,
            colorBlue: 0.95,
            isCompleted: true,
            isSkipped: false,
            source: "today"
        )
    }
}
