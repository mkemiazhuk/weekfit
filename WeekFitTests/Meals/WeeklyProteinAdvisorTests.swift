import XCTest
@testable import WeekFit

final class WeeklyProteinAdvisorTests: XCTestCase {

    func testEveningProteinDeficitTriggersCatchUpBand() {
        let now = date(year: 2026, month: 8, day: 11, hour: 19, minute: 0)
        let advice = WeeklyProteinAdvisor.advise(
            nutrition: nutrition(current: 70, goal: 150),
            plannedActivities: [],
            selectedDate: now,
            now: now,
            tomorrowDemand: .none,
            focus: .idle
        )

        XCTAssertEqual(advice.urgency, .catchUp)
        XCTAssertTrue(advice.prefersProteinCatchUp)
        XCTAssertEqual(advice.proteinRemainingToday, 80)
        XCTAssertGreaterThanOrEqual(advice.targetProteinGrams, 40)
        XCTAssertGreaterThan(advice.proteinFitWeight, 1.5)
    }

    func testPreSessionCapsProteinPushEvenWhenBehind() {
        let now = date(year: 2026, month: 8, day: 11, hour: 17, minute: 0)
        let session = CoachPlannedActivitySnapshot(
            date: now.addingTimeInterval(60 * 60),
            type: "workout",
            title: "Upper Body",
            durationMinutes: 55
        )
        let focus = CoachFocusSelection(
            activity: session,
            family: .strength,
            type: .upperBody,
            state: .upcoming,
            phase: .pre,
            source: .upcoming,
            minutesUntilStart: 60,
            minutesSinceEnd: nil
        )

        let advice = WeeklyProteinAdvisor.advise(
            nutrition: nutrition(current: 50, goal: 150),
            plannedActivities: [session],
            selectedDate: now,
            now: now,
            tomorrowDemand: .none,
            focus: focus
        )

        XCTAssertEqual(advice.urgency, .preSessionSoft)
        XCTAssertFalse(advice.prefersProteinCatchUp)
        XCTAssertLessThanOrEqual(advice.targetProteinGrams, 28)
        XCTAssertLessThan(advice.proteinFitWeight, 1.0)
    }

    func testCompletedStrengthSessionMarksPostSessionProtein() {
        let now = date(year: 2026, month: 8, day: 11, hour: 18, minute: 30)
        let session = CoachPlannedActivitySnapshot(
            date: now.addingTimeInterval(-90 * 60),
            type: "workout",
            title: "Lower Body",
            durationMinutes: 60,
            isCompleted: true
        )
        let focus = CoachFocusSelection(
            activity: session,
            family: .strength,
            type: .lowerBody,
            state: .finished,
            phase: .settledPost,
            source: .recentCompleted,
            minutesUntilStart: nil,
            minutesSinceEnd: 30
        )

        let advice = WeeklyProteinAdvisor.advise(
            nutrition: nutrition(current: 90, goal: 150),
            plannedActivities: [session],
            selectedDate: now,
            now: now,
            tomorrowDemand: .none,
            focus: focus
        )

        XCTAssertEqual(advice.urgency, .postSession)
        XCTAssertTrue(advice.prefersProteinCatchUp)
        XCTAssertGreaterThanOrEqual(advice.targetProteinGrams, 30)
    }

    func testHardTomorrowEveningProtectsWithProteinCatchUp() {
        let now = date(year: 2026, month: 8, day: 11, hour: 20, minute: 0)
        let advice = WeeklyProteinAdvisor.advise(
            nutrition: nutrition(current: 100, goal: 150),
            plannedActivities: [],
            selectedDate: now,
            now: now,
            tomorrowDemand: .hard,
            focus: .idle
        )

        XCTAssertEqual(advice.urgency, .protectTomorrow)
        XCTAssertTrue(advice.prefersProteinCatchUp)
    }

    func testWeekDeficitElevatesCatchUpAtMidday() {
        let today = date(year: 2026, month: 8, day: 11, hour: 15, minute: 0)
        // Tuesday Aug 11 2026 — week starts Sunday Aug 9 in US calendar often;
        // use completed low-protein meals on prior weekdays relative to selectedDate.
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return XCTFail("missing week start")
        }

        var priorMeals: [CoachPlannedActivitySnapshot] = []
        var day = weekStart
        while calendar.startOfDay(for: day) < calendar.startOfDay(for: today) {
            priorMeals.append(
                CoachPlannedActivitySnapshot(
                    date: day.addingTimeInterval(13 * 3600),
                    type: "meal",
                    title: "Low protein day",
                    durationMinutes: 20,
                    protein: 40,
                    isCompleted: true
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let advice = WeeklyProteinAdvisor.advise(
            nutrition: nutrition(current: 55, goal: 150),
            plannedActivities: priorMeals,
            selectedDate: today,
            now: today,
            tomorrowDemand: .none,
            focus: .idle
        )

        XCTAssertGreaterThanOrEqual(advice.weekDeficitGrams, 40)
        XCTAssertEqual(advice.urgency, .catchUp)
        XCTAssertTrue(advice.prefersProteinCatchUp)
    }

    func testProteinFitBonusPrefersTargetBandMealWhenCatchingUp() {
        let advice = WeeklyProteinAdvice(
            proteinRemainingToday: 70,
            targetProteinGrams: 42,
            bandLow: 34,
            bandHigh: 54,
            urgency: .catchUp,
            prefersProteinCatchUp: true,
            proteinFitWeight: 2.2,
            weekToDateProteinGrams: 200,
            weekElapsedDays: 3,
            weekDeficitGrams: 50,
            upcomingSeriousSessionCount: 0
        )

        let high = WeeklyProteinAdvisor.proteinFitBonus(mealProtein: 42, advice: advice)
        let low = WeeklyProteinAdvisor.proteinFitBonus(mealProtein: 12, advice: advice)
        XCTAssertGreaterThan(high, low)
    }

    func testMealRecommendationEnginePicksHigherProteinWhenCatchingUp() throws {
        let now = date(year: 2026, month: 8, day: 11, hour: 19, minute: 0)
        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: {
                var config = HumanBrainStateBuilder.Configuration()
                config.currentHour = 19
                return HumanBrainStateBuilder.make(config)
            }(),
            plannedActivities: [],
            recoveryContext: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 7.2),
            nutritionContext: nutrition(current: 60, goal: 150),
            source: "WeeklyProteinAdvisorTests"
        )

        let light = meal(id: "light", title: "Light bowl", protein: 14, calories: 380, carbs: 35, fats: 12)
        let proteinHeavy = meal(id: "protein", title: "Chicken plate", protein: 45, calories: 480, carbs: 28, fats: 14)

        let recommendation = try XCTUnwrap(
            MealRecommendationEngine.make(input: input, meals: [light, proteinHeavy], now: now)
        )

        XCTAssertEqual(recommendation.meal.id, "protein")
        XCTAssertTrue(
            recommendation.reason.contains("80") || recommendation.badge.lowercased().contains("protein"),
            "Expected protein catch-up copy, got badge=\(recommendation.badge) reason=\(recommendation.reason)"
        )
    }

    // MARK: - Helpers

    private func nutrition(current: Double, goal: Double) -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: current * 8,
            caloriesGoal: 2_200,
            proteinCurrent: current,
            proteinGoal: goal,
            waterCurrent: 1.5,
            waterGoal: 3.0
        )
    }

    private func meal(
        id: String,
        title: String,
        protein: Int,
        calories: Int,
        carbs: Int,
        fats: Int
    ) -> Meals {
        Meals(
            id: id,
            title: title,
            subtitle: "",
            imageName: "fork.knife",
            type: .highProtein,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: 5,
            benefits: [],
            ingredients: []
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
