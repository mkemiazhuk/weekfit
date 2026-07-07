import SwiftData
import XCTest
@testable import WeekFit

@MainActor
final class PlanViewModelPlannerDeleteTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testDeleteByIDRemovesActivityFromTimelineSource() throws {
        let viewModel = PlanViewModel()
        let drink = makeDrink(title: "Coffee")
        context.insert(drink)
        try context.save()

        var querySource = try fetchAllActivities()
        let revisionBeforeDelete = PlannedActivityRefreshSignature.make(from: querySource)
        let timelineBeforeDelete = viewModel.timelineItems(from: querySource, revision: revisionBeforeDelete)
        XCTAssertEqual(timelineBeforeDelete.map(\.id), [drink.id])

        viewModel.removePlannedActivities(withIDs: [drink.id], modelContext: context)

        querySource = try fetchAllActivities()
        let revisionAfterDelete = PlannedActivityRefreshSignature.make(from: querySource)
        let timelineAfterDelete = viewModel.timelineItems(from: querySource, revision: revisionAfterDelete)

        XCTAssertTrue(querySource.isEmpty)
        XCTAssertTrue(timelineAfterDelete.isEmpty)
        XCTAssertEqual(try remainingCount(for: drink.id, in: context), 0)
    }

    func testDeleteUsesLocalRevisionNotStaleParentRevisionForTimeline() throws {
        let viewModel = PlanViewModel()
        let drink = makeDrink(title: "Tea")
        context.insert(drink)
        try context.save()

        let activitiesBeforeDelete = try fetchAllActivities()
        let staleParentRevision = PlannedActivityRefreshSignature.make(from: activitiesBeforeDelete)
        viewModel.warmTimelineCache(from: activitiesBeforeDelete, revision: staleParentRevision)
        XCTAssertFalse(viewModel.timelineItems(from: activitiesBeforeDelete, revision: staleParentRevision).isEmpty)

        viewModel.removePlannedActivities(withIDs: [drink.id], modelContext: context)

        let activitiesAfterDelete = try fetchAllActivities()
        let localRevisionAfterDelete = PlannedActivityRefreshSignature.make(from: activitiesAfterDelete)
        let timelineAfterDelete = viewModel.timelineItems(
            from: activitiesAfterDelete,
            revision: localRevisionAfterDelete
        )

        XCTAssertTrue(activitiesAfterDelete.isEmpty)
        XCTAssertTrue(timelineAfterDelete.isEmpty)
    }

    func testWaterGroupDeleteRemovesAllResolvedDrinksFromTimeline() throws {
        let viewModel = PlanViewModel()
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 7, hour: 12, minute: 0, second: 0))!
        viewModel.selectedDate = baseDate

        let drinks = [
            makeWaterLog(milliliters: 250, date: baseDate),
            makeWaterLog(milliliters: 250, date: baseDate.addingTimeInterval(30))
        ]
        drinks.forEach { context.insert($0) }
        try context.save()

        var querySource = try fetchAllActivities()
        let revision = PlannedActivityRefreshSignature.make(from: querySource)
        let groupedTimeline = viewModel.timelineItems(from: querySource, revision: revision)
        XCTAssertEqual(groupedTimeline.count, 1)
        guard case .waterGroup(let groupedDrinks) = groupedTimeline[0] else {
            return XCTFail("Expected grouped water timeline item, got \(groupedTimeline)")
        }
        XCTAssertEqual(groupedDrinks.count, 2)

        viewModel.removePlannedActivities(withIDs: drinks.map(\.id), modelContext: context)

        querySource = try fetchAllActivities()
        let revisionAfterDelete = PlannedActivityRefreshSignature.make(from: querySource)
        let timelineAfterDelete = viewModel.timelineItems(from: querySource, revision: revisionAfterDelete)

        XCTAssertTrue(querySource.isEmpty)
        XCTAssertTrue(timelineAfterDelete.isEmpty)
    }

    func testDeletePersistsAcrossFreshModelContextFetch() throws {
        let viewModel = PlanViewModel()
        let drink = makeDrink(title: "Protein Shake")
        context.insert(drink)
        try context.save()

        viewModel.removePlannedActivities(withIDs: [drink.id], modelContext: context)

        let freshContext = ModelContext(container)
        XCTAssertTrue(try freshContext.fetch(FetchDescriptor<PlannedActivity>()).isEmpty)
        XCTAssertEqual(try remainingCount(for: drink.id, in: freshContext), 0)
    }

    private func fetchAllActivities() throws -> [PlannedActivity] {
        try context.fetch(FetchDescriptor<PlannedActivity>())
    }

    private func remainingCount(for activityID: String, in modelContext: ModelContext) throws -> Int {
        try PlannedActivityPersistenceService.remainingCount(for: activityID, in: modelContext)
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

    private func makeWaterLog(milliliters: Int, date: Date) -> PlannedActivity {
        PlannedActivity(
            date: date,
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
