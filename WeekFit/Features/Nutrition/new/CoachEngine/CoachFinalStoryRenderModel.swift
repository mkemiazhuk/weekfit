import SwiftUI

struct CoachFinalStoryRenderedSupportSignal: Hashable {
    let kind: CoachFinalStorySupportSignal.Kind
    let title: String
    let icon: String
    let colorFamily: CoachFinalStoryColorFamily

    var color: Color { colorFamily.color }
}

struct CoachFinalStoryRenderModel {
    let owner: CoachFinalStoryOwner
    let primaryFocus: CoachDayFocus
    let title: String
    let subtitle: String
    let badge: String
    let heroState: String
    let icon: String
    let colorFamily: CoachFinalStoryColorFamily
    let primaryRecommendation: String
    let avoidRecommendation: String
    let whatHappened: String
    let whatMattersNow: String
    let whatToDoNext: String
    let whatToAvoid: String
    let primaryActionTitle: String
    let primaryActionIcon: String
    let supportActions: [CoachSupportActionV3]
    let supportSignals: [CoachFinalStoryRenderedSupportSignal]

    var color: Color { colorFamily.color }

    init(story: CoachFinalStory) {
        self.owner = story.owner
        self.primaryFocus = story.primaryFocus
        self.title = story.title.resolved
        self.subtitle = story.subtitle.resolved
        self.badge = story.badgeState.resolved
        self.heroState = story.heroState.resolved
        self.icon = story.icon
        self.colorFamily = story.colorFamily
        self.primaryRecommendation = story.primaryRecommendation.resolved
        self.avoidRecommendation = story.avoidRecommendation.resolved
        self.whatHappened = story.whatHappened.resolved
        self.whatMattersNow = story.whatMattersNow.resolved
        self.whatToDoNext = story.whatToDoNext.resolved
        self.whatToAvoid = story.whatToAvoid.resolved
        self.primaryActionTitle = story.primaryAction.title.resolved
        self.primaryActionIcon = story.primaryAction.icon
        self.supportActions = story.supportActions
        self.supportSignals = CoachFinalStoryRenderModel.visibleSupportSignals(for: story)
    }
}

extension CoachFinalStoryRenderModel {
    static func visibleSupportSignals(for story: CoachFinalStory) -> [CoachFinalStoryRenderedSupportSignal] {
        let heroTexts = [
            story.title.resolved,
            story.subtitle.resolved,
            story.whatHappened.resolved,
            story.whatMattersNow.resolved,
            story.whatToDoNext.resolved,
            story.whatToAvoid.resolved,
            story.primaryRecommendation.resolved,
            story.avoidRecommendation.resolved,
            story.primaryAction.title.resolved
        ].map { value in
            normalized(value)
        }
        var seenEvidence = Set<String>()

        return story.supportSignals.compactMap { signal in
            let evidenceKey = supportEvidenceKey(for: signal.kind)
            guard seenEvidence.insert(evidenceKey).inserted else { return nil }

            let signalTitle = signal.title.resolved.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle = (isGenericSupportTitle(signalTitle)
                ? supportExplanation(for: signal.kind, owner: story.owner)
                : signalTitle)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !resolvedTitle.isEmpty else { return nil }
            guard !heroTexts.contains(normalized(resolvedTitle)) else { return nil }

            return CoachFinalStoryRenderedSupportSignal(
                kind: signal.kind,
                title: resolvedTitle,
                icon: signal.icon,
                colorFamily: colorFamily(for: signal.kind)
            )
        }
    }

    static func colorFamily(for signalKind: CoachFinalStorySupportSignal.Kind) -> CoachFinalStoryColorFamily {
        switch signalKind {
        case .hydration:
            return .hydration
        case .fuel:
            return .fuel
        case .recovery, .sleep:
            return .recovery
        case .activity:
            return .activity
        }
    }

    static func supportExplanation(
        for signalKind: CoachFinalStorySupportSignal.Kind,
        owner: CoachFinalStoryOwner
    ) -> String {
        let key: String
        switch signalKind {
        case .hydration:
            key = owner == .activityPreparation || owner == .activeActivity
                ? "coach.final.support.hydration.activity"
                : owner == .recovery || owner == .postActivityRecovery
                ? "coach.final.support.hydration.recovery"
                : "coach.final.support.hydration.stable"
        case .fuel:
            key = owner == .activityPreparation || owner == .activeActivity
                ? "coach.final.support.fuel.activity"
                : owner == .recovery || owner == .postActivityRecovery
                ? "coach.final.support.fuel.recovery"
                : "coach.final.support.fuel.stable"
        case .recovery:
            key = "coach.final.support.recovery"
        case .sleep:
            key = "coach.final.support.sleep"
        case .activity:
            key = "coach.final.support.activity"
        }

        return WeekFitLocalizedString(key)
    }

    static func supportEvidenceKey(for signalKind: CoachFinalStorySupportSignal.Kind) -> String {
        switch signalKind {
        case .hydration:
            return "hydration-status"
        case .fuel:
            return "nutrition-status"
        case .recovery:
            return "recovery-status"
        case .sleep:
            return "sleep-status"
        case .activity:
            return "activity-status"
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func isGenericSupportTitle(_ value: String) -> Bool {
        let normalized = normalized(value)
        return normalized.isEmpty ||
            normalized.contains("supports this story") ||
            normalized.contains("supports this conclusion") ||
            normalized.contains("is part of the decision")
    }
}
