import SwiftUI
import WeekFitPlanner

struct CoachFeelingSheetHost: View {
    let healthManager: HealthManager
    let plannedActivities: [PlannedActivity]
    let launch: CoachFeelingViewModel.Launch

    @StateObject private var viewModel: CoachFeelingViewModel

    init(
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity],
        launch: CoachFeelingViewModel.Launch
    ) {
        self.healthManager = healthManager
        self.plannedActivities = plannedActivities
        self.launch = launch
        _viewModel = StateObject(
            wrappedValue: CoachFeelingViewModel(
                healthManager: healthManager,
                plannedActivities: plannedActivities,
                launch: launch
            )
        )
    }

    var body: some View {
        CoachFeelingConversationView(viewModel: viewModel)
            .onAppear {
                viewModel.updatePlannedActivities(plannedActivities)
            }
            .onChange(of: plannedActivities.count) { _, _ in
                viewModel.updatePlannedActivities(plannedActivities)
            }
    }
}
