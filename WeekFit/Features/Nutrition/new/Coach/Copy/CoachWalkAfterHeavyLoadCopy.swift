import Foundation

/// Phase-specific copy for `walkAfterHeavyLoad` — scenario key unchanged.
enum CoachWalkAfterHeavyLoadCopy {

    typealias Phase = CoachWalkRecoveryActionCopy.Phase

    static func phase(for input: CoachCopyBuildInput) -> Phase {
        CoachWalkRecoveryActionCopy.phase(for: input)
    }

    static func phase(for context: CoachContext) -> Phase {
        CoachWalkRecoveryActionCopy.phase(for: context)
    }

    static func draft(for input: CoachCopyBuildInput) -> CoachCopyRegistryScenarios.Draft {
        switch phase(for: input) {
        case .upcoming:
            return upcomingDraft()
        case .live:
            return liveDraft()
        case .completed:
            return completedDraft(input: input)
        }
    }
}

// MARK: - Presentation

enum CoachWalkAfterHeavyLoadPresentation {

    static func todayTitle(
        for phase: CoachWalkAfterHeavyLoadCopy.Phase,
        hasSeriousWork: Bool,
        russian: Bool
    ) -> String {
        switch phase {
        case .upcoming:
            return russian ? "Прогулка после нагрузки" : "Recovery walk"
        case .live:
            return russian ? "На прогулке" : "On the walk"
        case .completed:
            if hasSeriousWork {
                return russian ? "Восстанавливаемся" : "Recovering now"
            }
            return russian ? "Плотный день позади" : "Heavy day done"
        }
    }

    static func coachHeadline(
        for phase: CoachWalkAfterHeavyLoadCopy.Phase,
        hasSeriousWork: Bool,
        russian: Bool
    ) -> String {
        todayTitle(for: phase, hasSeriousWork: hasSeriousWork, russian: russian)
    }

    static func teaserMessage(
        for phase: CoachWalkAfterHeavyLoadCopy.Phase,
        hasSeriousWork: Bool,
        russian: Bool
    ) -> String {
        switch phase {
        case .upcoming:
            return russian
                ? "Лёгкая прогулка — успокоить день."
                : "Easy walk to settle the day."
        case .live:
            return russian
                ? "Держите темп лёгким."
                : "Keep the pace easy."
        case .completed:
            if hasSeriousWork {
                return russian
                    ? "Остаток дня — восстановление."
                    : "Recovery is the job for the rest of today."
            }
            return russian
                ? "Остаток дня спокойный."
                : "Keep the rest of the day calm."
        }
    }

    static func phase(for context: CoachContext) -> CoachWalkAfterHeavyLoadCopy.Phase {
        CoachWalkAfterHeavyLoadCopy.phase(for: context)
    }
}

// MARK: - Draft packs

private extension CoachWalkAfterHeavyLoadCopy {

    static func upcomingDraft() -> CoachCopyRegistryScenarios.Draft {
        CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Big day behind you — this walk is about settling down.",
                "Плотный день позади — прогулка, чтобы успокоиться."
            ),
            recommendation: .en(
                "Let heart rate and pace drift down; nothing to prove.",
                "Пусть пульс и темп сами снижаются — доказывать нечего."
            ),
            avoid: .en(
                "Don't pick up pace or treat it like cardio.",
                "Не ускоряйтесь — это не кардио."
            ),
            nextAction: .en(
                "Keep it slow enough to speak in full sentences.",
                "Так медленно, чтобы спокойно разговаривать."
            )
        )
    }

    static func liveDraft() -> CoachCopyRegistryScenarios.Draft {
        CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Heavy day — keep this walk easy.",
                "Плотный день — держите прогулку лёгкой."
            ),
            recommendation: .en(
                "Let the walk release tension, not add another block.",
                "Пусть прогулка снимет напряжение, а не добавит новый блок."
            ),
            avoid: .en(
                "Don't speed up if the legs feel heavy.",
                "Не ускоряйтесь, если ноги тяжёлые."
            ),
            nextAction: .en(
                "Keep it slow enough to speak in full sentences.",
                "Так медленно, чтобы спокойно разговаривать."
            )
        )
    }

    static func completedDraft(input: CoachCopyBuildInput) -> CoachCopyRegistryScenarios.Draft {
        if input.modifiers.completedSeriousActivities != .none {
            return completedAfterSeriousWorkDraft()
        }
        return completedWalksOnlyDraft()
    }

    static func completedAfterSeriousWorkDraft() -> CoachCopyRegistryScenarios.Draft {
        CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Main work is done — the day can land calmly now.",
                "Основная работа уже сделана — день можно завершить спокойно."
            ),
            recommendation: .en(
                "Keep the rest of the day calm — no new hard block.",
                "Остаток дня — восстановление, без нового интенсивного блока."
            ),
            avoid: .en(
                "Do not force extra steps just to chase numbers.",
                "Не добавляйте нагрузку ради цифр."
            ),
            nextAction: .en(
                "Water, food as planned, then a bit of rest.",
                "Вода, еда по плану и немного отдыха."
            )
        )
    }

    static func completedWalksOnlyDraft() -> CoachCopyRegistryScenarios.Draft {
        CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Full day — the walks already helped things settle.",
                "Плотный день — прогулки уже помогли успокоиться."
            ),
            recommendation: .en(
                "Keep the rest of the day calm — nothing left to prove.",
                "Остаток дня спокойный — доказывать уже нечего."
            ),
            avoid: .en(
                "Do not force extra steps just to chase numbers.",
                "Не добавляйте шаги через силу только ради цифр."
            ),
            nextAction: .en(
                "Water, food as planned, then a bit of rest.",
                "Вода, еда по плану и немного отдыха."
            )
        )
    }
}
