import Foundation

/// Overlays limited-confidence copy when sleep/recovery did not sync.
enum CoachLimitedRecoveryCopyPolicy {

    static func apply(to pack: CoachCopyPack) -> CoachCopyPack {
        CoachCopyPack(
            scenario: pack.scenario,
            assessment: limitedAssessment(),
            recommendation: pack.recommendation,
            avoid: limitedAvoid(),
            nextAction: pack.nextAction,
            supportingSignals: pack.supportingSignals,
            warningLayer: pack.warningLayer
        )
    }

    private static func limitedAssessment() -> CoachCopySection {
        .single(.en(
            "Sleep wasn't recorded today, so I'm basing guidance on your plan and activity—not recovery metrics.",
            "Сегодня сон не записан, поэтому я ориентируюсь на ваш план и активность, а не на показатели восстановления."
        ))
    }

    private static func limitedAvoid() -> CoachCopySection {
        .single(.en(
            "Don't treat missing sleep as proof you're either ready or not ready.",
            "Если сон не записан, это ещё не значит, что вы готовы или не готовы."
        ))
    }
}
