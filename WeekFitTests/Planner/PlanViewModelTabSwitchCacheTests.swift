import XCTest
@testable import WeekFit

@MainActor
final class PlanViewModelTabSwitchCacheTests: XCTestCase {

    func testLoadCustomMealsIfNeededSkipsDuplicateStorage() {
        let viewModel = PlanViewModel()
        let storage = """
        [{"id":"meal-a","title":"Test","subtitle":"","imageName":"","type":"highProtein","calories":100,"protein":10,"carbs":10,"fats":5,"benefits":[],"ingredients":[]}]
        """

        viewModel.loadCustomMealsIfNeeded(from: storage)
        let firstCount = viewModel.customMeals.count

        viewModel.loadCustomMealsIfNeeded(from: storage)
        XCTAssertEqual(viewModel.customMeals.count, firstCount)
    }

    func testWarmDayKindCacheUsesRevisionWithoutRebuildWhenUnchanged() {
        let viewModel = PlanViewModel()
        let activities = [
            PlannedActivity(
                date: Date(),
                type: PlannerType.meal.title,
                title: "Lunch",
                durationMinutes: 20,
                icon: PlannerType.meal.icon,
                imageName: "",
                colorRed: 0,
                colorGreen: 0,
                colorBlue: 0
            )
        ]
        let revision = PlannedActivityRefreshSignature.make(from: activities)

        viewModel.warmDayKindCache(from: activities, revision: revision)
        let firstRevision = viewModel.dayKindCacheRevision

        viewModel.warmDayKindCache(from: activities, revision: revision)
        XCTAssertEqual(viewModel.dayKindCacheRevision, firstRevision)
    }

    func testTimelineItemsCacheReusesDerivedItemsForSameRevision() {
        let viewModel = PlanViewModel()
        let activities = [
            PlannedActivity(
                date: Date(),
                type: PlannerType.meal.title,
                title: "Breakfast",
                durationMinutes: 20,
                icon: PlannerType.meal.icon,
                imageName: "",
                colorRed: 0,
                colorGreen: 0,
                colorBlue: 0
            )
        ]
        let revision = PlannedActivityRefreshSignature.make(from: activities)

        let first = viewModel.timelineItems(from: activities, revision: revision)
        let second = viewModel.timelineItems(from: activities, revision: revision)

        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testWarmTimelineCachePopulatesDerivedItems() {
        let viewModel = PlanViewModel()
        let activities = [
            PlannedActivity(
                date: Date(),
                type: PlannerType.meal.title,
                title: "Lunch",
                durationMinutes: 20,
                icon: PlannerType.meal.icon,
                imageName: "",
                colorRed: 0,
                colorGreen: 0,
                colorBlue: 0
            )
        ]
        let revision = PlannedActivityRefreshSignature.make(from: activities)

        viewModel.warmTimelineCache(from: activities, revision: revision)
        let cached = viewModel.timelineItems(from: activities, revision: revision)

        XCTAssertFalse(cached.isEmpty)
    }

    func testCompactRevisionTokenIsStableAndCompact() {
        let revision = String(repeating: "a", count: 24_560)
        let token = PlannedActivityRefreshSignature.compactToken(from: revision)

        XCTAssertLessThan(token.count, 32)
        XCTAssertEqual(token, PlannedActivityRefreshSignature.compactToken(from: revision))
    }
}
