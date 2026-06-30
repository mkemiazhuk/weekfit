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
        timeOfDay: CoachTimeOfDay,
        russian: Bool
    ) -> String {
        switch phase {
        case .upcoming:
            return russian ? "Легкая прогулка" : "Recovery walk"
        case .live:
            return russian ? "На прогулке" : "On the walk"
        case .completed:
            if hasSeriousWork {
                return russian ? "Восстанавливаемся" : "Recovering now"
            }
            if CoachCopyClosureTiming.allowsDayClosurePhrasing(timeOfDay: timeOfDay) {
                return russian ? "Плотный день позади" : "Heavy day done"
            }
            return russian ? "Восстанавливаемся" : "Recovering now"
        }
    }

    static func coachHeadline(
        for phase: CoachWalkAfterHeavyLoadCopy.Phase,
        hasSeriousWork: Bool,
        timeOfDay: CoachTimeOfDay,
        russian: Bool
    ) -> String {
        todayTitle(for: phase, hasSeriousWork: hasSeriousWork, timeOfDay: timeOfDay, russian: russian)
    }

    static func teaserMessage(
        for phase: CoachWalkAfterHeavyLoadCopy.Phase,
        hasSeriousWork: Bool,
        timeOfDay: CoachTimeOfDay,
        russian: Bool
    ) -> String {
        switch phase {
        case .upcoming:
            return russian
                ? "Спокойный темп поможет организму восстановиться."
                : "Easy walk to settle the day."
        case .live:
            return russian
                ? "Держите темп лёгким."
                : "Keep the pace easy."
        case .completed:
            if hasSeriousWork {
                if CoachCopyClosureTiming.allowsRestOfDayPhrasing(timeOfDay) {
                    return russian
                        ? "Остаток дня — восстановление."
                        : "Recovery is the job for the rest of today."
                }
                return russian
                    ? "Сегодня без лишней интенсивности."
                    : "Keep optional intensity off the table today."
            }
            if CoachCopyClosureTiming.allowsRestOfDayPhrasing(timeOfDay) {
                return russian
                    ? "Остаток дня спокойный."
                    : "Keep the rest of the day calm."
            }
            return russian
                ? "Сегодня без лишней интенсивности."
                : "Keep today calm — nothing to prove."
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
                "After a heavy day — this walk is about settling down.",
                "После нагрузки — прогулка, чтобы успокоиться."
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
            return completedAfterSeriousWorkDraft(input: input)
        }
        return completedWalksOnlyDraft(input: input)
    }

    static func completedAfterSeriousWorkDraft(input: CoachCopyBuildInput) -> CoachCopyRegistryScenarios.Draft {
        if CoachCopyClosureTiming.allowsDayClosurePhrasing(
            timeOfDay: input.timeOfDay,
            conversationPhase: input.conversationPhase
        ) {
            return CoachCopyRegistryScenarios.Draft(
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
                nextAction: CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(
                    mealWindowOpen: input.mealWindowOpen
                )
            )
        }

        if CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay) {
            return CoachCopyRegistryScenarios.Draft(
                assessment: .en(
                    "Main work is done — the evening can stay calm.",
                    "Основная работа сделана — вечер можно провести спокойно."
                ),
                recommendation: .en(
                    "Keep the rest of the day calm — no new hard block.",
                    "Остаток дня спокойный — без нового тяжёлого блока."
                ),
                avoid: .en(
                    "Do not force extra steps just to chase numbers.",
                    "Не добавляйте нагрузку ради цифр."
                ),
                nextAction: CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(
                    mealWindowOpen: input.mealWindowOpen
                )
            )
        }

        return CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Main work is done — keep today easy from here.",
                "Основная работа сделана — дальше без спешки."
            ),
            recommendation: .en(
                "No new hard block today — recovery comes first.",
                "Сегодня без нового тяжёлого блока — восстановление в приоритете."
            ),
            avoid: .en(
                "Do not force extra steps just to chase numbers.",
                "Не добавляйте нагрузку ради цифр."
            ),
            nextAction: CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(
                mealWindowOpen: input.mealWindowOpen
            )
        )
    }

    static func completedWalksOnlyDraft(input: CoachCopyBuildInput) -> CoachCopyRegistryScenarios.Draft {
        if CoachCopyClosureTiming.allowsDayClosurePhrasing(
            timeOfDay: input.timeOfDay,
            conversationPhase: input.conversationPhase
        ) {
            return CoachCopyRegistryScenarios.Draft(
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
                nextAction: CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(
                    mealWindowOpen: input.mealWindowOpen
                )
            )
        }

        if CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay) {
            return CoachCopyRegistryScenarios.Draft(
                assessment: .en(
                    "The walks helped things settle — keep the evening calm.",
                    "Прогулки помогли успокоиться — вечер без спешки."
                ),
                recommendation: .en(
                    "Keep the rest of the day calm — nothing left to prove.",
                    "Остаток дня спокойный — доказывать уже нечего."
                ),
                avoid: .en(
                    "Do not force extra steps just to chase numbers.",
                    "Не добавляйте шаги через силу только ради цифр."
                ),
                nextAction: CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(
                    mealWindowOpen: input.mealWindowOpen
                )
            )
        }

        return CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "The walks already helped things settle.",
                "Прогулки уже помогли успокоиться."
            ),
            recommendation: .en(
                "Keep today calm — hold an easy rhythm from here.",
                "Сегодня спокойно — дальше держите лёгкий ритм."
            ),
            avoid: .en(
                "Do not force extra steps just to chase numbers.",
                "Не добавляйте шаги через силу только ради цифр."
            ),
            nextAction: CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(
                mealWindowOpen: input.mealWindowOpen
            )
        )
    }
}
