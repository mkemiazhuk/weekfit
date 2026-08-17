import Foundation

/// Presentation-only overlay: injects one learned-discovery nudge into supporting why-rows.
/// Does not change scenario routing or fingerprints.
enum CoachDiscoveryAdaptCopyPolicy {

    static func apply(
        to pack: CoachCopyPack,
        input: CoachInputSnapshot,
        context: CoachContext
    ) -> CoachCopyPack {
        let learned = CoachLearnedContextBuilder.build(input: input, context: context)
        guard let nudge = learned.primaryNudge else { return pack }

        return CoachCopyPack(
            scenario: pack.scenario,
            assessment: pack.assessment,
            recommendation: pack.recommendation,
            avoid: pack.avoid,
            nextAction: pack.nextAction,
            supportingSignals: merge(nudge.message, into: pack.supportingSignals),
            warningLayer: pack.warningLayer
        )
    }

    private static func merge(
        _ line: CoachBilingualText,
        into section: CoachCopySection
    ) -> CoachCopySection {
        var lines = section.lines.filter {
            $0.english != line.english && $0.russian != line.russian
        }
        // Personal evidence first in the why-row budget (max 3).
        lines.insert(line, at: 0)
        return CoachCopySection(lines: Array(lines.prefix(3)))
    }
}
