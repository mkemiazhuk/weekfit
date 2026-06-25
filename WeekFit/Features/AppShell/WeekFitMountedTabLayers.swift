import SwiftUI

// Equatable wrappers skip body re-evaluation for inactive mounted tabs during tab switches.
// Data revisions ensure real updates still reach the active tab.

private struct TodayTabLayer: View, Equatable {
    let isActive: Bool
    let returnToTodayTrigger: UUID
    let nutritionRevision: UUID
    let plannedActivitiesRevision: String
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var selectedDate: Date
    let onSelectTab: (WeekFitTab) -> Void
    @ObservedObject var coachInputProvider: CoachInputProvider

    static func == (lhs: TodayTabLayer, rhs: TodayTabLayer) -> Bool {
        guard lhs.isActive == rhs.isActive else { return false }
        guard lhs.isActive else { return true }
        return lhs.returnToTodayTrigger == rhs.returnToTodayTrigger &&
            lhs.nutritionRevision == rhs.nutritionRevision &&
            lhs.plannedActivitiesRevision == rhs.plannedActivitiesRevision
    }

    var body: some View {
        TodayView(
            authViewModel: authViewModel,
            selectedDate: $selectedDate,
            returnToTodayTrigger: returnToTodayTrigger,
            onSelectTab: onSelectTab
        )
        .environment(\.tabIsActive, isActive)
        .environmentObject(coachInputProvider)
        .zIndex(isActive ? 1 : 0)
    }
}

private struct CoachTabLayer: View, Equatable {
    let isActive: Bool
    let coachStateID: UUID
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var coachInputProvider: CoachInputProvider

    static func == (lhs: CoachTabLayer, rhs: CoachTabLayer) -> Bool {
        guard lhs.isActive == rhs.isActive else { return false }
        guard lhs.isActive else { return true }
        return lhs.coachStateID == rhs.coachStateID
    }

    var body: some View {
        ExpertCoachView(authViewModel: authViewModel)
            .environment(\.tabIsActive, isActive)
            .environmentObject(coachInputProvider)
            .zIndex(isActive ? 1 : 0)
    }
}

private struct MealsTabLayer: View, Equatable {
    let isActive: Bool
    let nutritionRevision: UUID
    let nutritionResult: NutritionResult?
    @ObservedObject var authViewModel: AuthViewModel

    static func == (lhs: MealsTabLayer, rhs: MealsTabLayer) -> Bool {
        guard lhs.isActive == rhs.isActive else { return false }
        guard lhs.isActive else { return true }
        return lhs.nutritionRevision == rhs.nutritionRevision
    }

    var body: some View {
        MealsView(
            authViewModel: authViewModel,
            nutritionResult: nutritionResult
        )
        .environment(\.tabIsActive, isActive)
        .zIndex(isActive ? 1 : 0)
    }
}

private struct CalendarTabLayer: View, Equatable {
    let isActive: Bool
    let plannedActivitiesRevision: String
    @ObservedObject var viewModel: PlanViewModel
    @ObservedObject var authViewModel: AuthViewModel

    static func == (lhs: CalendarTabLayer, rhs: CalendarTabLayer) -> Bool {
        guard lhs.isActive == rhs.isActive else { return false }
        guard lhs.isActive else { return true }
        return lhs.plannedActivitiesRevision == rhs.plannedActivitiesRevision &&
            lhs.viewModel.plannerInteractionToken == rhs.viewModel.plannerInteractionToken
    }

    var body: some View {
        WeekPlannerView(
            viewModel: viewModel,
            plannedActivitiesRevision: plannedActivitiesRevision,
            authViewModel: authViewModel
        )
        .environment(\.tabIsActive, isActive)
        .zIndex(isActive ? 1 : 0)
    }
}

enum WeekFitMountedTabLayers {
    @ViewBuilder
    static func today(
        isActive: Bool,
        returnToTodayTrigger: UUID,
        nutritionRevision: UUID,
        plannedActivitiesRevision: String,
        authViewModel: AuthViewModel,
        selectedDate: Binding<Date>,
        onSelectTab: @escaping (WeekFitTab) -> Void,
        coachInputProvider: CoachInputProvider
    ) -> some View {
        EquatableView(
            content: TodayTabLayer(
                isActive: isActive,
                returnToTodayTrigger: returnToTodayTrigger,
                nutritionRevision: nutritionRevision,
                plannedActivitiesRevision: plannedActivitiesRevision,
                authViewModel: authViewModel,
                selectedDate: selectedDate,
                onSelectTab: onSelectTab,
                coachInputProvider: coachInputProvider
            )
        )
    }

    @ViewBuilder
    static func coach(
        isActive: Bool,
        coachStateID: UUID,
        authViewModel: AuthViewModel,
        coachInputProvider: CoachInputProvider
    ) -> some View {
        EquatableView(
            content: CoachTabLayer(
                isActive: isActive,
                coachStateID: coachStateID,
                authViewModel: authViewModel,
                coachInputProvider: coachInputProvider
            )
        )
    }

    @ViewBuilder
    static func meals(
        isActive: Bool,
        nutritionRevision: UUID,
        nutritionResult: NutritionResult?,
        authViewModel: AuthViewModel
    ) -> some View {
        EquatableView(
            content: MealsTabLayer(
                isActive: isActive,
                nutritionRevision: nutritionRevision,
                nutritionResult: nutritionResult,
                authViewModel: authViewModel
            )
        )
    }

    @ViewBuilder
    static func calendar(
        isActive: Bool,
        plannedActivitiesRevision: String,
        viewModel: PlanViewModel,
        authViewModel: AuthViewModel
    ) -> some View {
        EquatableView(
            content: CalendarTabLayer(
                isActive: isActive,
                plannedActivitiesRevision: plannedActivitiesRevision,
                viewModel: viewModel,
                authViewModel: authViewModel
            )
        )
    }
}
