import Foundation

/// Presentation labels and styling for the planner day chip.
/// Underlying training logic lives in `DayTrainingType` / `DayTrainingTypeClassifier`.
enum PlanDayKind: Equatable {
    case endurance
    case load
    case mixed
    case recovery
    case open

    var label: String {
        switch self {
        case .endurance: return WeekFitLocalizedString("planner.dayKind.endurance")
        case .load: return WeekFitLocalizedString("planner.dayKind.load")
        case .mixed: return WeekFitLocalizedString("planner.dayKind.mixed")
        case .recovery: return WeekFitLocalizedString("planner.dayKind.recovery")
        case .open: return WeekFitLocalizedString("planner.dayKind.open")
        }
    }

    var legendLabel: String {
        switch self {
        case .endurance: return WeekFitLocalizedString("planner.legend.endurance")
        case .load: return WeekFitLocalizedString("planner.legend.highLoad")
        case .mixed: return WeekFitLocalizedString("planner.legend.mixed")
        case .recovery: return WeekFitLocalizedString("planner.legend.recovery")
        case .open: return WeekFitLocalizedString("planner.dayKind.open")
        }
    }

    var barCount: Int {
        switch self {
        case .endurance: return 4
        case .load: return 3
        case .mixed: return 2
        case .recovery: return 1
        case .open: return 0
        }
    }

    init(trainingType: DayTrainingType) {
        switch trainingType {
        case .recovery: self = .recovery
        case .endurance: self = .endurance
        case .strength: self = .load
        case .mixed: self = .mixed
        }
    }
}

enum PlanDayKindResolver {

    nonisolated static func resolve(activities: [PlannedActivity]) -> PlanDayKind {
        guard !activities.isEmpty else {
            return .open
        }

        guard let trainingType = DayTrainingTypeClassifier.classify(activities: activities) else {
            return .open
        }

        return PlanDayKind(trainingType: trainingType)
    }
}
