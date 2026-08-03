import Foundation

/// Visual status for a proposed plan change row.
enum CoachTodayPlanChangeKind: String, Equatable, Sendable {
    case keep
    case adjust
    case remove
}

/// One scannable row in “Что изменится”.
struct CoachTodayPlanChangeItem: Identifiable, Equatable, Sendable {
    let id: String
    let kind: CoachTodayPlanChangeKind
    let title: String
}

/// One selectable timeline recommendation for today.
struct CoachTodayPlanTimelineItem: Identifiable, Equatable, Sendable {
    let id: String
    let activityID: String?
    let timeLabel: String
    let activityTitle: String
    let actionLabel: String
    let rationale: String
    let kind: CoachTodayPlanChangeKind
    let isSelectedByDefault: Bool
}

/// Presentation-only model for the AI daily plan consultation.
/// Built from existing Coach signals and planned activities — does not invent health data.
struct CoachTodayPlanConsultationPresentation: Equatable, Sendable {
    let eyebrow: String
    let headline: String
    let summary: String
    let reasonLabel: String
    let reasonValue: String
    let changesLabel: String
    let changesValue: String
    let changesSectionTitle: String
    let changeItems: [CoachTodayPlanChangeItem]
    let timelineSectionTitle: String
    let timelineItems: [CoachTodayPlanTimelineItem]
    let noteSectionTitle: String
    let noteHeadline: String
    let noteBody: String
    let primaryCTATitle: String
    let secondaryCTATitle: String
    let scenario: CoachScenarioKey

    var hasSelectableChanges: Bool {
        !timelineItems.isEmpty
    }
}
