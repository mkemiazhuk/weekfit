import Foundation

enum ReflectionCopy {

    static func message(for event: UnderstandingEvent) -> String {
        switch (event.beliefID, event.change, event.maturity) {
        case (.sleepConsistencyRecovery, .emerged, .emerging):
            return CoachState.localized(
                english: "I've started noticing something about your sleep. When your bedtime stays consistent, your recovery tends to be stronger the next day.",
                russian: "Я начинаю замечать кое-что про ваш сон: когда вы ложитесь спать в одно и то же время, восстановление на следующий день обычно выше."
            )
        case (.sleepConsistencyRecovery, .emerged, .established), (.sleepConsistencyRecovery, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. Your recovery is consistently stronger when your sleep timing stays steady.",
                russian: "Теперь я в этом увереннее: восстановление стабильно выше, когда вы засыпаете примерно в одно и то же время."
            )
        case (.sleepDurationRecovery, .emerged, .emerging):
            return CoachState.localized(
                english: "I'm starting to notice that when your sleep gets closer to 7–7.5 hours, your recovery tends to come back stronger.",
                russian: "Я начинаю замечать: когда сон приближается к 7–7,5 часам, восстановление обычно возвращается сильнее."
            )
        case (.sleepDurationRecovery, .emerged, .established), (.sleepDurationRecovery, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. When you reach around 7–7.5 hours of sleep, your recovery usually comes back stronger.",
                russian: "Теперь я в этом увереннее: когда сон держится около 7–7,5 часов, восстановление обычно заметно сильнее."
            )
        case (.lateBedtimeRecovery, .emerged, .emerging):
            return CoachState.localized(
                english: "I'm starting to notice that when you go to bed later than usual, your recovery the next morning tends to be lower.",
                russian: "Я начинаю замечать: когда вы ложитесь позже обычного, восстановление утром обычно ниже."
            )
        case (.lateBedtimeRecovery, .emerged, .established), (.lateBedtimeRecovery, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. Later bedtimes usually leave your recovery lower the next morning.",
                russian: "Теперь я в этом увереннее: если вы ложитесь позже обычного, восстановление на следующее утро обычно ниже."
            )
        case (.heavyLoadRecoveryLag, .emerged, .emerging):
            return CoachState.localized(
                english: "I'm starting to notice that after your harder training days, your recovery often needs a day or two to come back.",
                russian: "Я начинаю замечать, что после тяжёлых тренировочных дней восстановлению часто нужен ещё день-два, чтобы вернуться."
            )
        case (.heavyLoadRecoveryLag, .emerged, .established), (.heavyLoadRecoveryLag, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. After harder training days, your recovery often needs a day or two to bounce back.",
                russian: "Теперь я в этом увереннее: после тяжёлых тренировочных дней восстановлению обычно нужен ещё день-два, чтобы вернуться."
            )
        case (.recoveryAfterRestDay, .emerged, .emerging):
            return CoachState.localized(
                english: "I'm starting to notice that when you give yourself a lighter day after heavier work, your recovery tends to come back better.",
                russian: "Я начинаю замечать, что когда после более тяжёлой нагрузки вы даёте себе лёгкий день, восстановление чаще возвращается лучше."
            )
        case (.recoveryAfterRestDay, .emerged, .established), (.recoveryAfterRestDay, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. A lighter day after heavier work usually helps your recovery come back stronger.",
                russian: "Теперь я в этом увереннее: лёгкий день после более тяжёлой нагрузки обычно помогает восстановлению вернуться сильнее."
            )
        case (.consecutiveHardDaysFatigue, .emerged, .emerging):
            return CoachState.localized(
                english: "I'm starting to notice that when harder training days stack up back to back, your recovery tends to dip more noticeably.",
                russian: "Я начинаю замечать, что когда несколько тяжёлых тренировочных дней идут подряд, восстановление проседает заметнее."
            )
        case (.consecutiveHardDaysFatigue, .emerged, .established), (.consecutiveHardDaysFatigue, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. When harder training days stack back to back, your recovery usually dips more noticeably.",
                russian: "Теперь я в этом увереннее: когда тяжёлые тренировочные дни идут подряд, восстановление обычно проседает заметнее."
            )
        case (.underfuelingRecovery, .emerged, .emerging):
            return CoachState.localized(
                english: "I'm starting to notice that when you finish days significantly underfueled, your recovery often comes back weaker.",
                russian: "Я начинаю замечать, что когда день заканчивается с заметным недобором энергии, восстановление чаще возвращается слабее."
            )
        case (.underfuelingRecovery, .emerged, .established), (.underfuelingRecovery, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. When you finish days significantly underfueled, your recovery usually comes back weaker.",
                russian: "Теперь я в этом увереннее: когда день заканчивается с заметным недобором энергии, восстановление обычно возвращается слабее."
            )
        default:
            return CoachState.localized(
                english: "I've learned something new about how your body responds over time.",
                russian: "Я узнал кое-что новое о том, как ваше тело меняется со временем."
            )
        }
    }

    static func reflectionKind(for event: UnderstandingEvent) -> ReflectionKind {
        switch event.change {
        case .emerged:
            return .newDiscovery
        case .strengthened:
            return .confirmation
        }
    }
}
