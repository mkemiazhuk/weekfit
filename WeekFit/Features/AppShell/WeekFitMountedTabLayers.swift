import SwiftUI

// Equatable wrappers skip body re-evaluation for inactive mounted tabs during tab switches.
// Data revisions ensure real updates still reach the active tab.
// `appearanceInvalidationToken` forces a full refresh when Light/Dark/Night Comfort changes —
// without it, root chrome updates while EquatableView freezes tab content (mixed theme).

private struct TodayTabLayer: View, Equatable {
    let isActive: Bool
    let appearanceInvalidationToken: UInt64
    let returnToTodayTrigger: UUID
    let nutritionRevision: UUID
    let plannedActivitiesRevision: String
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var selectedDate: Date
    let onSelectTab: (WeekFitTab) -> Void
    @ObservedObject var coachInputProvider: CoachInputProvider

    static func == (lhs: TodayTabLayer, rhs: TodayTabLayer) -> Bool {
        guard lhs.isActive == rhs.isActive else { return false }
        // Always refresh on appearance change — inactive layers can still paint under
        // translucent active content and otherwise keep a stale Light/Dark snapshot.
        guard lhs.appearanceInvalidationToken == rhs.appearanceInvalidationToken else { return false }
        guard lhs.isActive else { return true }
        return lhs.returnToTodayTrigger == rhs.returnToTodayTrigger &&
            lhs.nutritionRevision == rhs.nutritionRevision &&
            lhs.plannedActivitiesRevision == rhs.plannedActivitiesRevision
    }

    var body: some View {
        let _ = TodayStartupDiagnostics.child(
            "TodayTabLayer.body",
            detail: "isActive=\(isActive) plannedRevLen=\(plannedActivitiesRevision.count) appearanceToken=\(appearanceInvalidationToken)"
        )
        return TodayView(
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
    let appearanceInvalidationToken: UInt64
    let coachStateID: UUID
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var coachInputProvider: CoachInputProvider

    static func == (lhs: CoachTabLayer, rhs: CoachTabLayer) -> Bool {
        guard lhs.isActive == rhs.isActive else { return false }
        guard lhs.appearanceInvalidationToken == rhs.appearanceInvalidationToken else { return false }
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
    let appearanceInvalidationToken: UInt64
    let nutritionRevision: UUID
    let nutritionResult: NutritionResult?
    @ObservedObject var authViewModel: AuthViewModel

    static func == (lhs: MealsTabLayer, rhs: MealsTabLayer) -> Bool {
        guard lhs.isActive == rhs.isActive else { return false }
        guard lhs.appearanceInvalidationToken == rhs.appearanceInvalidationToken else { return false }
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

enum WeekFitMountedTabLayers {
    @ViewBuilder
    static func today(
        isActive: Bool,
        appearanceInvalidationToken: UInt64,
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
                appearanceInvalidationToken: appearanceInvalidationToken,
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
        appearanceInvalidationToken: UInt64,
        coachStateID: UUID,
        authViewModel: AuthViewModel,
        coachInputProvider: CoachInputProvider
    ) -> some View {
        EquatableView(
            content: CoachTabLayer(
                isActive: isActive,
                appearanceInvalidationToken: appearanceInvalidationToken,
                coachStateID: coachStateID,
                authViewModel: authViewModel,
                coachInputProvider: coachInputProvider
            )
        )
    }

    @ViewBuilder
    static func meals(
        isActive: Bool,
        appearanceInvalidationToken: UInt64,
        nutritionRevision: UUID,
        nutritionResult: NutritionResult?,
        authViewModel: AuthViewModel
    ) -> some View {
        EquatableView(
            content: MealsTabLayer(
                isActive: isActive,
                appearanceInvalidationToken: appearanceInvalidationToken,
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
        // No EquatableView here: planner hosts its own @Query and must refresh on every SwiftData change.
        CalendarTabLayer(
            isActive: isActive,
            plannedActivitiesRevision: plannedActivitiesRevision,
            viewModel: viewModel,
            authViewModel: authViewModel
        )
    }
}

private struct CalendarTabLayer: View {
    let isActive: Bool
    let plannedActivitiesRevision: String
    @ObservedObject var viewModel: PlanViewModel
    @ObservedObject var authViewModel: AuthViewModel

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
