import Foundation

/// Phase-specific copy for `walkRecoveryAction` — scenario key unchanged.
enum CoachWalkRecoveryActionCopy {

    enum Phase: Equatable, Sendable {
        case upcoming
        case live
        case completed
    }

    static func phase(for input: CoachCopyBuildInput) -> Phase {
        phase(
            sessionPhase: input.sessionPhase,
            activityState: input.activityState
        )
    }

    static func phase(for context: CoachContext) -> Phase {
        phase(
            sessionPhase: context.sessionPhase,
            activityState: context.activityState
        )
    }

    private static func phase(
        sessionPhase: CoachSessionPhase,
        activityState: CoachActivityState
    ) -> Phase {
        switch sessionPhase {
        case .pre:
            return .upcoming
        case .during:
            return .live
        case .immediatePost, .settledPost, .evening:
            return .completed
        default:
            switch activityState {
            case .upcoming:
                return .upcoming
            case .active:
                return .live
            case .justFinished, .finished:
                return .completed
            case .none:
                return .upcoming
            }
        }
    }

    static func draft(for input: CoachCopyBuildInput) -> CoachCopyRegistryScenarios.Draft {
        switch phase(for: input) {
        case .upcoming:
            return upcomingDraft()
        case .live:
            return liveDraft()
        case .completed:
            return completedDraft()
        }
    }
}

// MARK: - Presentation chrome

enum CoachWalkRecoveryActionPresentation {

    static func todayTitle(for phase: CoachWalkRecoveryActionCopy.Phase, russian: Bool) -> String {
        switch phase {
        case .upcoming:
            return russian ? "Прогулка для ног" : "Leg flush walk"
        case .live:
            return russian ? "На прогулке" : "On the walk"
        case .completed:
            return russian ? "Прогулка завершена" : "Walk completed"
        }
    }

    static func coachHeadline(for phase: CoachWalkRecoveryActionCopy.Phase, russian: Bool) -> String {
        switch phase {
        case .upcoming:
            return russian ? "Прогулка для ног" : "Recovery walk"
        case .live:
            return russian ? "На прогулке" : "On the walk"
        case .completed:
            return russian ? "Прогулка завершена" : "Walk completed"
        }
    }

    static func teaserMessage(for phase: CoachWalkRecoveryActionCopy.Phase, russian: Bool) -> String {
        switch phase {
        case .upcoming:
            return russian
                ? "Лёгкие шаги — разогнать ноги."
                : "Easy steps to flush the legs."
        case .live:
            return russian
                ? "Держите темп лёгким."
                : "Keep the pace easy."
        case .completed:
            return russian
                ? "Остаток дня — спокойно."
                : "Keep the rest of the day calm."
        }
    }

    static func phase(for context: CoachContext) -> CoachWalkRecoveryActionCopy.Phase {
        CoachWalkRecoveryActionCopy.phase(for: context)
    }
}

// MARK: - Draft packs

private extension CoachWalkRecoveryActionCopy {

    static func upcomingDraft() -> CoachCopyRegistryScenarios.Draft {
        CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Short walk to flush the legs after hard work.",
                "Короткая прогулка — разогнать ноги после нагрузки."
            ),
            recommendation: .en(
                "Use the walk to recover — easy steps, not more load.",
                "Используйте прогулку для восстановления — лёгкие шаги, не новая нагрузка."
            ),
            avoid: .en(
                "Don't speed up or add hills for extra credit.",
                "Не ускоряйтесь и не лезьте в горки ради галочки."
            ),
            nextAction: .en(
                "Ten minutes easy — slow enough to talk.",
                "Десять минут легко — так, чтобы спокойно говорить."
            )
        )
    }

    static func liveDraft() -> CoachCopyRegistryScenarios.Draft {
        CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Recovery walk — keep it easy.",
                "Прогулка для восстановления — держите легко."
            ),
            recommendation: .en(
                "Easy steps only — blood flow, not more load.",
                "Только лёгкие шаги — кровоток, не новая нагрузка."
            ),
            avoid: .en(
                "Don't speed up or chase pace on tired legs.",
                "Не ускоряйтесь и не гонитесь за темпом на уставших ногах."
            ),
            nextAction: .en(
                "Keep it slow enough to speak in full sentences.",
                "Так медленно, чтобы спокойно разговаривать."
            )
        )
    }

    static func completedDraft() -> CoachCopyRegistryScenarios.Draft {
        CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "The walk has already helped the body ease out of load.",
                "Прогулка уже помогла мягко сбросить нагрузку."
            ),
            recommendation: .en(
                "Keep the rest of the day calm — no new hard block.",
                "Теперь держите остаток дня спокойно — без нового интенсивного блока."
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
