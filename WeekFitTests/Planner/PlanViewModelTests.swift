import XCTest
@testable import WeekFit

@MainActor
final class PlanViewModelTests: XCTestCase {
    private var viewModel: PlanViewModel!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        viewModel = PlanViewModel()
        calendar = viewModel.calendar
    }

    func testSelectedDayActivitiesFiltersSkippedAndSortsByTime() {
        let day = calendar.startOfDay(for: Date())
        let morning = calendar.date(byAdding: .hour, value: 8, to: day)!
        let evening = calendar.date(byAdding: .hour, value: 18, to: day)!
        let skipped = calendar.date(byAdding: .hour, value: 12, to: day)!

        let activities = [
            makeActivity(date: evening, title: "Evening"),
            makeActivity(date: morning, title: "Morning"),
            makeActivity(date: skipped, title: "Skipped", isSkipped: true)
        ]

        viewModel.selectedDate = day
        let result = viewModel.selectedDayActivities(from: activities)

        XCTAssertEqual(result.map(\.title), ["Morning", "Evening"])
    }

    func testCalculateProgressReturnsBaselineWhenDayIsEmpty() {
        viewModel.selectedDate = Date()
        XCTAssertEqual(viewModel.calculateProgress(from: []), 0.18, accuracy: 0.001)
    }

    func testPlannerInteractionTokenChangesWhenSelectedDateChanges() {
        let firstToken = viewModel.plannerInteractionToken
        viewModel.selectedDate = calendar.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        XCTAssertNotEqual(viewModel.plannerInteractionToken, firstToken)
    }

    private func makeActivity(
        date: Date,
        title: String,
        isSkipped: Bool = false
    ) -> PlannedActivity {
        PlannedActivity(
            date: date,
            type: "workout",
            title: title,
            durationMinutes: 30,
            icon: "figure.run",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9,
            isSkipped: isSkipped
        )
    }
}
