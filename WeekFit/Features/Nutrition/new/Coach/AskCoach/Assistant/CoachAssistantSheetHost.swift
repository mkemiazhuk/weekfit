import SwiftUI
import WeekFitPlanner

struct CoachAssistantSheetHost: View {
    let healthManager: HealthManager
    let plannedActivities: [PlannedActivity]
    let nutritionContext: CoachNutritionContext?
    let launch: CoachAssistantViewModel.Launch
    var onAction: ((CoachAssistantChoiceAction) -> Void)?

    @StateObject private var viewModel: CoachAssistantViewModel

    init(
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity],
        nutritionContext: CoachNutritionContext?,
        launch: CoachAssistantViewModel.Launch,
        onAction: ((CoachAssistantChoiceAction) -> Void)? = nil
    ) {
        self.healthManager = healthManager
        self.plannedActivities = plannedActivities
        self.nutritionContext = nutritionContext
        self.launch = launch
        self.onAction = onAction
        _viewModel = StateObject(
            wrappedValue: CoachAssistantViewModel(
                healthManager: healthManager,
                plannedActivities: plannedActivities,
                nutritionContext: nutritionContext,
                launch: launch
            )
        )
    }

    var body: some View {
        NavigationStack {
            CoachAssistantChatView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.updatePlannedActivities(plannedActivities)
            viewModel.updateNutritionContext(nutritionContext)
        }
        .onChange(of: plannedActivities.count) { _, _ in
            viewModel.updatePlannedActivities(plannedActivities)
        }
        .onChange(of: viewModel.pendingAction) { _, action in
            guard let action else { return }
            onAction?(action)
            viewModel.clearPendingAction()
        }
    }
}
