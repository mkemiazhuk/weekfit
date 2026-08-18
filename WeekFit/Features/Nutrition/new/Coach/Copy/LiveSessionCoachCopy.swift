import Foundation

/// Activity-aware copy while a session is live.
///
/// Interprets intensity against the *intent* of the activity, then fills
/// each hero section with a different job so Coach does not repeat the same
/// decision four times.
enum LiveSessionCoachCopy {

    enum Intent: Equatable {
        case recoveryEasy
        case enduranceAerobic
        case enduranceHard
        case strength
        case racket
        case heat
    }

    static func isLiveSession(_ input: CoachCopyBuildInput) -> Bool {
        input.sessionPhase == .during || input.activityState == .active
    }

    static func apply(
        to draft: CoachCopyRegistryScenarios.Draft,
        input: CoachCopyBuildInput
    ) -> CoachCopyRegistryScenarios.Draft {
        guard isLiveSession(input) else { return draft }

        let intent = intent(for: input)
        let zone = input.liveHeartRateZone
        let decision = decision(for: intent, zone: zone)

        return CoachCopyRegistryScenarios.Draft(
            assessment: assessment(for: input, intent: intent, decision: decision, fallback: draft.assessment),
            recommendation: recommendation(for: input, intent: intent, decision: decision, fallback: draft.recommendation),
            avoid: avoid(intent: intent, decision: decision, fallback: draft.avoid),
            nextAction: nextAction(for: input, intent: intent, decision: decision, fallback: draft.nextAction)
        )
    }

    static func teaser(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard isLiveSession(input) else { return nil }
        let intent = intent(for: input)
        let decision = decision(for: intent, zone: input.liveHeartRateZone)
        switch decision {
        case .easeOff:
            return .en("Ease back a little.", "Чуть сбавьте.")
        case .onTrack:
            switch intent {
            case .recoveryEasy:
                return .en("Keep this one easy.", "Держите легко.")
            case .enduranceHard:
                return .en("Work the effort, then reset.", "Работайте, потом сбрасывайте.")
            case .strength:
                return .en("Clean reps over load.", "Чистые повторы важнее веса.")
            case .racket:
                return .en("Point by point.", "Розыгрыш за розыгрышем.")
            case .heat:
                return .en("Stay in control of the heat.", "Держите жар под контролем.")
            case .enduranceAerobic:
                return .en("You're right where you should be.", "Вы там, где нужно.")
            }
        case .pushSustainable:
            return .en("Hold this effort.", "Держите это усилие.")
        }
    }

    static func whyLines(for input: CoachCopyBuildInput) -> [CoachBilingualText] {
        guard isLiveSession(input) else { return [] }
        let intent = intent(for: input)
        let decision = decision(for: intent, zone: input.liveHeartRateZone)
        var lines: [CoachBilingualText] = []

        if shouldExplainHydration(input: input, intent: intent, decision: decision) {
            lines.append(.en(
                "You're behind on hydration, so keeping this session easy is the better call.",
                "Воды пока мало — поэтому лучше не поднимать интенсивность."
            ))
        }

        if shouldExplainFuel(input: input, intent: intent, decision: decision) {
            if !input.mealWindowOpen {
                lines.append(.en(
                    "You haven't eaten yet today. No need to push the intensity before your first meal.",
                    "Сегодня ещё не было еды — до первого приёма пищи незачем давить."
                ))
            } else {
                lines.append(.en(
                    "Fuel is lagging today's load, so this is not the moment to add intensity.",
                    "Еды пока меньше, чем просит день — сейчас не время добавлять интенсивность."
                ))
            }
        }

        if shouldExplainRecovery(input: input, intent: intent) {
            if input.dayReadiness.sleepIsLow {
                lines.append(.en(
                    "Sleep was short, so keeping this session easy is the right call.",
                    "Сон был коротким — поэтому лучше держать эту сессию лёгкой."
                ))
            } else {
                lines.append(.en(
                    "Recovery is still catching up, so easy effort is the better call.",
                    "Тело ещё не восстановилось — поэтому лучше без лишней интенсивности."
                ))
            }
        }

        return Array(lines.prefix(2))
    }

    // MARK: - Intent

    static func intent(for input: CoachCopyBuildInput) -> Intent {
        switch input.scenario {
        case .walkAfterHeavyLoad, .walkRecoveryAction, .walkLightDay, .walkEveningWindDown,
             .duringRecovery:
            return .recoveryEasy
        case .duringStrength:
            return .strength
        case .duringRacket:
            return .racket
        case .saunaActive:
            return .heat
        case .duringEndurance:
            if input.activityType == .hiit { return .enduranceHard }
            return .enduranceAerobic
        default:
            switch input.activityType {
            case .walk, .yoga, .stretching, .breathing:
                return .recoveryEasy
            case .upperBody, .lowerBody, .core, .fullBody:
                return .strength
            case .tennis, .squash:
                return .racket
            case .sauna:
                return .heat
            case .hiit:
                return .enduranceHard
            default:
                return .enduranceAerobic
            }
        }
    }

    private enum Decision {
        case onTrack
        case easeOff
        case pushSustainable
    }

    private static func decision(for intent: Intent, zone: Int?) -> Decision {
        guard let zone else { return .onTrack }
        switch intent {
        case .recoveryEasy:
            return zone >= 3 ? .easeOff : .onTrack
        case .enduranceAerobic:
            if zone >= 4 { return .easeOff }
            if zone == 3 { return .pushSustainable }
            return .onTrack
        case .enduranceHard:
            return zone >= 5 ? .easeOff : .onTrack
        case .strength, .racket:
            return zone >= 5 ? .easeOff : .onTrack
        case .heat:
            return zone >= 4 ? .easeOff : .onTrack
        }
    }

    // MARK: - Sections

    private static func assessment(
        for input: CoachCopyBuildInput,
        intent: Intent,
        decision: Decision,
        fallback: CoachBilingualText
    ) -> CoachBilingualText {
        switch (intent, decision) {
        case (.recoveryEasy, .easeOff):
            return recoveryEaseOffAssessment(input)
        case (.recoveryEasy, _):
            return recoveryOnTrackAssessment(input)
        case (.enduranceAerobic, .easeOff):
            return enduranceSubject(
                input,
                en: "This is drifting harder than the session needs.",
                ru: "Нагрузка уходит выше, чем нужно этой сессии."
            )
        case (.enduranceAerobic, .pushSustainable):
            return enduranceSubject(
                input,
                en: "You're in the work — hold it here, don't drift higher.",
                ru: "Вы в рабочей зоне — держите, не уходите выше."
            )
        case (.enduranceAerobic, .onTrack):
            return enduranceSubject(
                input,
                en: "You're right where you should be — keep going.",
                ru: "Вы там, где нужно — продолжайте."
            )
        case (.enduranceHard, .easeOff):
            return .en(
                "Max effort is fine in a burst — don't live there between intervals.",
                "Максимум нормален вспышкой — не живите там между интервалами."
            )
        case (.enduranceHard, _):
            return .en(
                "HIIT is live — hard reps, honest recovery between.",
                "HIIT идёт — тяжёлые отрезки, честный отдых между ними."
            )
        case (.strength, .easeOff):
            return .en(
                "Heart rate is spiked — rest until you can own the next set.",
                "Пульс взлетел — отдохните, пока не будете готовы к следующему подходу."
            )
        case (.strength, _):
            return fallback
        case (.racket, .easeOff):
            return .en(
                "The rallies are hot — use the next changeover to settle.",
                "Розыгрыши жёсткие — на смене сторон дайте себе выдохнуть."
            )
        case (.racket, _):
            return fallback
        case (.heat, .easeOff):
            return .en(
                "Heat plus high heart rate — shorten this round.",
                "Жар и высокий пульс — сократите этот заход."
            )
        case (.heat, _):
            return fallback
        }
    }

    private static func recommendation(
        for input: CoachCopyBuildInput,
        intent: Intent,
        decision: Decision,
        fallback: CoachBilingualText
    ) -> CoachBilingualText {
        let cap = zoneOneCapLabel()
        switch (intent, decision) {
        case (.recoveryEasy, .easeOff):
            if isWalkLike(input), let cap {
                return .en(
                    "Come back under \(cap) and walk at a comfortable pace.",
                    "Вернитесь ниже \(cap) и идите комфортным шагом."
                )
            }
            return .en(
                "Slow down until breathing is easy again.",
                "Замедлитесь, пока дыхание снова не станет лёгким."
            )
        case (.recoveryEasy, _):
            if isWalkLike(input), let cap {
                return .en(
                    "Stay below \(cap) and walk at a comfortable pace.",
                    "Держитесь ниже \(cap) и идите комфортным шагом."
                )
            }
            if isWalkLike(input) {
                return .en(
                    "Walk at a comfortable pace — easy enough to talk.",
                    "Идите комфортным шагом — так, чтобы спокойно разговаривать."
                )
            }
            return .en(
                "Stay in easy range — nothing to prove here.",
                "Оставайтесь в лёгкой зоне — тут нечего доказывать."
            )
        case (.enduranceAerobic, .easeOff):
            return .en(
                "Ease back until breathing is conversational again.",
                "Сбавьте, пока снова не сможете спокойно говорить."
            )
        case (.enduranceAerobic, .pushSustainable):
            return .en(
                "Hold this — if sentences get short, back off one notch.",
                "Держите так — если фразы становятся короткими, чуть сбавьте."
            )
        case (.enduranceAerobic, .onTrack):
            if input.liveHeartRateZone != nil {
                return .en(
                    "Keep this conversational pace to the end.",
                    "Держите разговорный темп до конца."
                )
            }
            return fallback
        case (.enduranceHard, .easeOff):
            return .en(
                "Use the next recovery interval until breathing settles.",
                "Следующий отдых — пока дыхание не успокоится."
            )
        case (.enduranceHard, _):
            return fallback
        case (.strength, .easeOff):
            return .en(
                "Take the full rest — then the next set with clean form.",
                "Отдохните полностью — потом следующий подход с чистой техникой."
            )
        case (.strength, _):
            return fallback
        case (.racket, .easeOff):
            return .en(
                "Play the next points within yourself, not at full stretch.",
                "Следующие очки играйте в себе, не на пределе."
            )
        case (.racket, _):
            return fallback
        case (.heat, _):
            return fallback
        }
    }

    private static func avoid(
        intent: Intent,
        decision: Decision,
        fallback: CoachBilingualText
    ) -> CoachBilingualText {
        switch (intent, decision) {
        case (.recoveryEasy, .onTrack):
            return .en(
                "Don't turn it into a power walk or errands sprint.",
                "Не превращайте это в спортивную ходьбу или бег по делам."
            )
        case (.recoveryEasy, .easeOff):
            return .en(
                "Don't chase pace just because the legs feel warm.",
                "Не гонитесь за темпом только потому, что ноги разогрелись."
            )
        case (.enduranceAerobic, .onTrack), (.enduranceAerobic, .pushSustainable):
            return fallback
        case (.enduranceAerobic, .easeOff):
            return .en(
                "Don't add surges you'll pay for later in the session.",
                "Не добавляйте рывки, за которые потом заплатите."
            )
        case (.enduranceHard, .onTrack):
            return fallback
        case (.enduranceHard, .easeOff):
            return .en(
                "Don't skip the recovery interval to chase the score.",
                "Не пропускайте отдых между интервалами ради цифр."
            )
        case (.strength, .onTrack), (.racket, .onTrack), (.heat, .onTrack):
            return fallback
        case (.strength, .easeOff):
            return .en(
                "Don't jump into the next set while you're still gasping.",
                "Не идите в следующий подход, пока ещё задыхаетесь."
            )
        case (.racket, .easeOff):
            return .en(
                "Don't chase every ball at full stretch.",
                "Не лезьте за каждым мячом на пределе."
            )
        case (.heat, .easeOff):
            return .en(
                "Don't stay in longer to prove toughness.",
                "Не сидите дольше, чтобы доказать себе характер."
            )
        default:
            return fallback
        }
    }

    private static func nextAction(
        for input: CoachCopyBuildInput,
        intent: Intent,
        decision: Decision,
        fallback: CoachBilingualText
    ) -> CoachBilingualText {
        let minutes = max(input.focusDurationMinutes, 0)
        switch (intent, decision) {
        case (.recoveryEasy, _):
            if minutes > 0 {
                return .en(
                    "Another \(minutesPhrase(minutes)) easy minutes is enough.",
                    "Ещё \(minutes) лёгких минут достаточно."
                )
            }
            return .en(
                "Stay easy until the planned time is done.",
                "Держите легко до конца запланированного времени."
            )
        case (.enduranceAerobic, .easeOff):
            return .en(
                "One easier minute, then settle back into the planned pace.",
                "Минута полегче — потом вернитесь в запланированный темп."
            )
        case (.enduranceHard, .easeOff):
            return .en(
                "Finish this interval, then take the full rest.",
                "Доделайте этот отрезок — потом полный отдых."
            )
        default:
            return fallback
        }
    }

    // MARK: - Why gates

    private static func shouldExplainHydration(
        input: CoachCopyBuildInput,
        intent: Intent,
        decision: Decision
    ) -> Bool {
        guard input.safetyAlert != .hydrationCritical else { return false }
        guard input.modifiers.hydrationBehind || input.hydrationState.isBehind else { return false }
        switch intent {
        case .recoveryEasy, .heat:
            return true
        case .enduranceAerobic:
            return decision == .easeOff || decision == .onTrack
        case .enduranceHard, .strength, .racket:
            return false
        }
    }

    private static func shouldExplainFuel(
        input: CoachCopyBuildInput,
        intent: Intent,
        decision: Decision
    ) -> Bool {
        guard input.safetyAlert != .fuelCritical else { return false }
        let behind = input.modifiers.fuelBehind || input.fuelState.isBehind || !input.mealWindowOpen
        guard behind else { return false }
        switch intent {
        case .recoveryEasy:
            return true
        case .enduranceAerobic:
            return decision != .pushSustainable
        default:
            return false
        }
    }

    private static func shouldExplainRecovery(input: CoachCopyBuildInput, intent: Intent) -> Bool {
        guard input.dayReadiness.isLowRecovery || input.dayReadiness.sleepIsLow else { return false }
        switch intent {
        case .recoveryEasy, .enduranceAerobic:
            return true
        default:
            return false
        }
    }

    // MARK: - Subject helpers (quality audit tokens)

    private static func recoveryOnTrackAssessment(_ input: CoachCopyBuildInput) -> CoachBilingualText {
        if input.isFocusHikeLike {
            return .en(
                "Keep this hike easy — today it counts as recovery.",
                "Держите хайкинг легко — сегодня это восстановление."
            )
        }
        switch input.activityType {
        case .yoga:
            return .en(
                "Keep this yoga easy — today it counts as recovery.",
                "Держите йогу мягко — сегодня это восстановление."
            )
        case .stretching:
            return .en(
                "Keep this stretch easy — today it counts as recovery.",
                "Держите растяжку мягко — сегодня это восстановление."
            )
        case .breathing:
            return .en(
                "Keep this breath work easy — today it counts as recovery.",
                "Держите дыхание мягко — сегодня это восстановление."
            )
        default:
            return .en(
                "Keep this walk easy — today it counts as recovery.",
                "Держите прогулку легко — сегодня это восстановление."
            )
        }
    }

    private static func recoveryEaseOffAssessment(_ input: CoachCopyBuildInput) -> CoachBilingualText {
        if input.isFocusHikeLike {
            return .en(
                "This hike is running hotter than it needs to — today it still counts as recovery.",
                "Хайкинг идёт интенсивнее, чем нужно — сегодня это всё равно восстановление."
            )
        }
        switch input.activityType {
        case .yoga:
            return .en(
                "This yoga is running hotter than it needs to — today it still counts as recovery.",
                "Йога идёт интенсивнее, чем нужно — сегодня это всё равно восстановление."
            )
        case .stretching:
            return .en(
                "This stretch is running hotter than it needs to — today it still counts as recovery.",
                "Растяжка идёт интенсивнее, чем нужно — сегодня это всё равно восстановление."
            )
        case .breathing:
            return .en(
                "This breath work is running hotter than it needs to — today it still counts as recovery.",
                "Дыхание идёт интенсивнее, чем нужно — сегодня это всё равно восстановление."
            )
        default:
            return .en(
                "This walk is running hotter than it needs to — today it still counts as recovery.",
                "Прогулка идёт интенсивнее, чем нужно — сегодня это всё равно восстановление."
            )
        }
    }

    private static func isWalkLike(_ input: CoachCopyBuildInput) -> Bool {
        input.activityType == .walk
            || input.isFocusHikeLike
            || input.scenario == .walkRecoveryAction
            || input.scenario == .walkAfterHeavyLoad
            || input.scenario == .walkLightDay
            || input.scenario == .walkEveningWindDown
    }

    private static func enduranceSubject(
        _ input: CoachCopyBuildInput,
        en: String,
        ru: String
    ) -> CoachBilingualText {
        switch input.activityType {
        case .cycling:
            return .en("You're on the bike — \(lowercaseFirst(en))", "Вы на велосипеде — \(lowercaseFirst(ru))")
        case .running:
            return .en("You're in the run — \(lowercaseFirst(en))", "Вы в пробежке — \(lowercaseFirst(ru))")
        case .swimming:
            return .en("You're in the water — \(lowercaseFirst(en))", "Вы в бассейне — \(lowercaseFirst(ru))")
        default:
            return .en(en, ru)
        }
    }

    private static func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    private static func zoneOneCapLabel() -> String? {
        let label = HeartRateZones.bpmRangeLabel(for: 1)
        let digits = label.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return "\(digits) bpm"
    }

    private static func minutesPhrase(_ minutes: Int) -> String {
        minutes == 1 ? "1" : "\(minutes)"
    }
}
