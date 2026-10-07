import SwiftUI
import WeekFitPlanner

/// Owns Ask Coach conversation state for the Coach-tab sheet.
struct AskCoachSheetHost: View {
    enum Launch: Equatable {
        case chooser
        case question(AskCoachQuestion)
        case reviewFocus
    }

    let healthManager: HealthManager
    let plannedActivities: [PlannedActivity]
    let launch: Launch

    @StateObject private var viewModel: AskCoachViewModel

    init(
        healthManager: HealthManager,
        plannedActivities: [PlannedActivity],
        launch: Launch
    ) {
        self.healthManager = healthManager
        self.plannedActivities = plannedActivities
        self.launch = launch
        _viewModel = StateObject(
            wrappedValue: AskCoachViewModel(
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )
        )
    }

    var body: some View {
        AskCoachConversationView(viewModel: viewModel)
            .onAppear {
                viewModel.updatePlannedActivities(plannedActivities)
                switch launch {
                case .chooser:
                    break
                case .question(let question):
                    if viewModel.selectedQuestion == nil {
                        viewModel.selectQuestion(question)
                    }
                case .reviewFocus:
                    if viewModel.turns.isEmpty {
                        viewModel.reviewFocus()
                    }
                }
            }
            .onChange(of: plannedActivities.count) { _, _ in
                viewModel.updatePlannedActivities(plannedActivities)
            }
    }
}
