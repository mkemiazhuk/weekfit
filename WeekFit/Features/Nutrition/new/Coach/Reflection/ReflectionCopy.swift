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
        case (.proteinTrainingDayRecovery, .emerged, .emerging):
            return CoachState.localized(
                english: "I've noticed that on training days with higher protein, your recovery the next day tends to come back stronger.",
                russian: "Я заметил: в тренировочные дни с более высоким белком восстановление на следующий день обычно возвращается сильнее."
            )
        case (.proteinTrainingDayRecovery, .emerged, .established), (.proteinTrainingDayRecovery, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. Higher-protein training days tend to leave your next-day recovery stronger.",
                russian: "Теперь я в этом увереннее: тренировочные дни с более высоким белком обычно оставляют восстановление на следующий день сильнее."
            )
        case (.postWorkoutProteinRecovery, .emerged, .emerging):
            return CoachState.localized(
                english: "I've noticed that when you get more protein soon after harder workouts, your recovery the next day tends to look better.",
                russian: "Я заметил: когда после более тяжёлых тренировок вы быстрее набираете белок, восстановление на следующий день обычно выглядит лучше."
            )
        case (.postWorkoutProteinRecovery, .emerged, .established), (.postWorkoutProteinRecovery, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. More protein soon after harder workouts tends to support stronger next-day recovery.",
                russian: "Теперь я в этом увереннее: больше белка вскоре после тяжёлых тренировок обычно поддерживает более сильное восстановление на следующий день."
            )
        case (.hardTrainingLowRecoveryCost, .emerged, .emerging):
            return CoachState.localized(
                english: "I've noticed that when you push hard while still poorly recovered, the next day's recovery tends to take a bigger hit.",
                russian: "Я заметил: когда вы нагружаетесь, будучи ещё плохо восстановленными, восстановление на следующий день обычно проседает сильнее."
            )
        case (.hardTrainingLowRecoveryCost, .emerged, .established), (.hardTrainingLowRecoveryCost, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. Hard training while poorly recovered tends to cost more on the next day's recovery.",
                russian: "Теперь я в этом увереннее: тяжёлая нагрузка при слабом восстановлении обычно сильнее бьёт по восстановлению на следующий день."
            )
        case (.carbsTrainingDayRecovery, .emerged, .emerging):
            return CoachState.localized(
                english: "I've noticed that on harder training days with higher carbs, your recovery the next day tends to come back stronger.",
                russian: "Я заметил: в более тяжёлые тренировочные дни с более высоким углеводом восстановление на следующий день обычно возвращается сильнее."
            )
        case (.carbsTrainingDayRecovery, .emerged, .established), (.carbsTrainingDayRecovery, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. Higher-carb harder training days tend to leave your next-day recovery stronger.",
                russian: "Теперь я в этом увереннее: более тяжёлые тренировочные дни с более высоким углеводом обычно оставляют восстановление на следующий день сильнее."
            )
        case (.lateHardTrainingSleep, .emerged, .emerging):
            return CoachState.localized(
                english: "I've noticed that when harder sessions finish late, the following night's sleep tends to come in shorter.",
                russian: "Я заметил: когда более тяжёлые тренировки заканчиваются поздно, сон следующей ночи обычно получается короче."
            )
        case (.lateHardTrainingSleep, .emerged, .established), (.lateHardTrainingSleep, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. Late hard sessions tend to leave the following night's sleep shorter.",
                russian: "Теперь я в этом увереннее: поздние тяжёлые тренировки обычно оставляют сон следующей ночи короче."
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
