import Foundation

/// Human-facing Discovery copy. Observational tone — no confidence %, sample counts, or debug terms.
enum CoachDiscoveryCopy {

    struct Content: Equatable, Sendable {
        let title: String
        let body: String
        let proof: String
    }

    static func content(
        for beliefID: CoachBeliefID,
        observations: [CoachDailyObservation] = CoachObservationStore.allObservations()
    ) -> Content {
        Content(
            title: title(for: beliefID),
            body: body(for: beliefID, observations: observations),
            proof: proof(for: beliefID)
        )
    }

    static func content(
        for offer: CoachDiscoveryOffer,
        observations: [CoachDailyObservation] = CoachObservationStore.allObservations()
    ) -> Content {
        content(for: offer.beliefID, observations: observations)
    }

    static func content(
        for discovery: CoachDiscovery,
        observations: [CoachDailyObservation] = CoachObservationStore.allObservations()
    ) -> Content {
        content(for: discovery.beliefID, observations: observations)
    }

    static func familyLabel(for family: CoachDiscoveryFamily) -> String {
        switch family {
        case .sleep:
            return CoachState.localized(english: "Sleep", russian: "Сон")
        case .training:
            return CoachState.localized(english: "Training", russian: "Тренировки")
        case .nutrition:
            return CoachState.localized(english: "Nutrition", russian: "Питание")
        case .timing:
            return CoachState.localized(english: "Timing", russian: "Тайминг")
        }
    }

    static var noticedEyebrow: String {
        CoachState.localized(
            english: "I noticed something",
            russian: "Я кое-что заметил"
        )
    }

    static var gotItAction: String {
        CoachState.localized(
            english: "Got it",
            russian: "Понятно"
        )
    }

    // MARK: - Title

    private static func title(for beliefID: CoachBeliefID) -> String {
        switch beliefID {
        case .sleepConsistencyRecovery:
            return CoachState.localized(
                english: "Consistent bedtime",
                russian: "Стабильное время сна"
            )
        case .sleepDurationRecovery:
            return CoachState.localized(
                english: "Sleep duration",
                russian: "Длительность сна"
            )
        case .lateBedtimeRecovery:
            return CoachState.localized(
                english: "Later bedtimes",
                russian: "Поздний отбой"
            )
        case .heavyLoadRecoveryLag:
            return CoachState.localized(
                english: "Hard training recovery",
                russian: "Восстановление после тяжёлых дней"
            )
        case .recoveryAfterRestDay:
            return CoachState.localized(
                english: "Lighter days help",
                russian: "Лёгкие дни помогают"
            )
        case .consecutiveHardDaysFatigue:
            return CoachState.localized(
                english: "Stacked hard days",
                russian: "Тяжёлые дни подряд"
            )
        case .underfuelingRecovery:
            return CoachState.localized(
                english: "Underfueling",
                russian: "Недобор энергии"
            )
        case .proteinTrainingDayRecovery:
            return CoachState.localized(
                english: "Protein on training days",
                russian: "Белок в тренировочные дни"
            )
        case .postWorkoutProteinRecovery:
            return CoachState.localized(
                english: "Protein after workouts",
                russian: "Белок после тренировок"
            )
        case .hardTrainingLowRecoveryCost:
            return CoachState.localized(
                english: "Training while depleted",
                russian: "Тренировки без восстановления"
            )
        case .carbsTrainingDayRecovery:
            return CoachState.localized(
                english: "Carbs on training days",
                russian: "Углеводы в тренировочные дни"
            )
        case .lateHardTrainingSleep:
            return CoachState.localized(
                english: "Late hard sessions",
                russian: "Поздние тяжёлые тренировки"
            )
        }
    }

    // MARK: - Body

    private static func body(
        for beliefID: CoachBeliefID,
        observations: [CoachDailyObservation]
    ) -> String {
        switch beliefID {
        case .sleepConsistencyRecovery:
            return CoachState.localized(
                english: "Your recovery tends to be stronger the next day when your bedtime stays consistent.",
                russian: "Восстановление на следующий день обычно выше, когда вы ложитесь спать примерно в одно и то же время."
            )
        case .sleepDurationRecovery:
            if let threshold = SleepDurationBeliefEvaluator.analyze(observations: observations)?.sufficientSleepThresholdMinutes {
                let hoursText = formatHoursRange(aroundMinutes: threshold)
                return CoachState.localized(
                    english: "When your sleep gets closer to about \(hoursText), your recovery usually comes back stronger.",
                    russian: "Когда сон приближается к \(hoursTextRu(aroundMinutes: threshold)), восстановление обычно возвращается заметно сильнее."
                )
            }
            return CoachState.localized(
                english: "When your sleep gets closer to the amount that works for you, your recovery usually comes back stronger.",
                russian: "Когда сон приближается к длительности, которая вам подходит, восстановление обычно возвращается заметно сильнее."
            )
        case .lateBedtimeRecovery:
            return CoachState.localized(
                english: "When you go to bed later than usual, your recovery the next morning tends to be lower.",
                russian: "Когда вы ложитесь позже обычного, восстановление утром обычно ниже."
            )
        case .heavyLoadRecoveryLag:
            return CoachState.localized(
                english: "After your harder training days, your recovery often needs a day or two to come back.",
                russian: "После тяжёлых тренировочных дней восстановлению часто нужен ещё день-два, чтобы вернуться."
            )
        case .recoveryAfterRestDay:
            return CoachState.localized(
                english: "A lighter day after heavier work usually helps your recovery come back stronger.",
                russian: "Лёгкий день после более тяжёлой нагрузки обычно помогает восстановлению вернуться сильнее."
            )
        case .consecutiveHardDaysFatigue:
            return CoachState.localized(
                english: "When harder training days stack back to back, your recovery usually dips more noticeably.",
                russian: "Когда тяжёлые тренировочные дни идут подряд, восстановление обычно проседает заметнее."
            )
        case .underfuelingRecovery:
            return CoachState.localized(
                english: "When you finish days significantly underfueled, your recovery often comes back weaker.",
                russian: "Когда день заканчивается с заметным недобором энергии, восстановление чаще возвращается слабее."
            )
        case .proteinTrainingDayRecovery:
            if let evaluation = ProteinTrainingDayRecoveryBeliefEvaluator.analyze(observations: observations),
               evaluation.recoveryDelta > 0 {
                let low = evaluation.lowProteinMedianGrams + 10
                let high = evaluation.highProteinMedianGrams + 10
                return CoachState.localized(
                    english: "On training days around \(low)–\(high) g protein, your next-day recovery tends to come back stronger.",
                    russian: "В тренировочные дни около \(low)–\(high) г белка восстановление на следующий день обычно возвращается сильнее."
                )
            }
            return CoachState.localized(
                english: "On training days with higher protein, your next-day recovery tends to come back stronger.",
                russian: "В тренировочные дни с более высоким белком восстановление на следующий день обычно возвращается сильнее."
            )
        case .postWorkoutProteinRecovery:
            if let evaluation = PostWorkoutProteinRecoveryBeliefEvaluator.analyze(observations: observations),
               evaluation.recoveryDelta > 0 {
                let target = max(evaluation.splitThresholdGrams, 30)
                return CoachState.localized(
                    english: "When you get closer to about \(target) g protein soon after harder workouts, next-day recovery tends to look better.",
                    russian: "Когда после более тяжёлых тренировок вы быстрее набираете около \(target) г белка, восстановление на следующий день обычно выглядит лучше."
                )
            }
            return CoachState.localized(
                english: "When you get more protein soon after harder workouts, next-day recovery tends to look better.",
                russian: "Когда после более тяжёлых тренировок вы быстрее набираете белок, восстановление на следующий день обычно выглядит лучше."
            )
        case .hardTrainingLowRecoveryCost:
            return CoachState.localized(
                english: "Pushing hard while still poorly recovered tends to cost more on the next day's recovery.",
                russian: "Тяжёлая нагрузка при слабом восстановлении обычно сильнее бьёт по восстановлению на следующий день."
            )
        case .carbsTrainingDayRecovery:
            if let evaluation = CarbsTrainingDayRecoveryBeliefEvaluator.analyze(observations: observations),
               evaluation.recoveryDelta > 0 {
                let low = evaluation.lowCarbsMedianGrams + 15
                let high = evaluation.highCarbsMedianGrams + 15
                return CoachState.localized(
                    english: "On harder training days around \(low)–\(high) g carbs, your next-day recovery tends to come back stronger.",
                    russian: "В более тяжёлые тренировочные дни около \(low)–\(high) г углеводов восстановление на следующий день обычно возвращается сильнее."
                )
            }
            return CoachState.localized(
                english: "On harder training days with higher carbs, your next-day recovery tends to come back stronger.",
                russian: "В более тяжёлые тренировочные дни с более высоким углеводом восстановление на следующий день обычно возвращается сильнее."
            )
        case .lateHardTrainingSleep:
            if let evaluation = LateHardTrainingSleepBeliefEvaluator.analyze(observations: observations),
               evaluation.sleepDropMinutes > 0 {
                let hour = evaluation.lateThresholdMinutes / 60
                return CoachState.localized(
                    english: "When harder sessions finish after about \(hour):00, the following night's sleep tends to come in shorter.",
                    russian: "Когда более тяжёлые тренировки заканчиваются после \(hour):00, сон следующей ночи обычно получается короче."
                )
            }
            return CoachState.localized(
                english: "When harder sessions finish late, the following night's sleep tends to come in shorter.",
                russian: "Когда более тяжёлые тренировки заканчиваются поздно, сон следующей ночи обычно получается короче."
            )
        }
    }

    // MARK: - Proof

    private static func proof(for beliefID: CoachBeliefID) -> String {
        switch beliefID.discoveryFamily {
        case .sleep:
            return CoachState.localized(
                english: "Based on your recent nights.",
                russian: "На основе ваших недавних ночей."
            )
        case .training:
            return CoachState.localized(
                english: "Based on your recent training days.",
                russian: "На основе ваших недавних тренировочных дней."
            )
        case .nutrition:
            return CoachState.localized(
                english: "Based on your recent nutrition and recovery.",
                russian: "На основе вашего недавнего питания и восстановления."
            )
        case .timing:
            return CoachState.localized(
                english: "Based on your recent patterns.",
                russian: "На основе ваших недавних паттернов."
            )
        }
    }

    // MARK: - Formatting

    private static func formatHoursRange(aroundMinutes: Int) -> String {
        let hours = Double(aroundMinutes) / 60.0
        let low = (hours * 2).rounded() / 2
        let high = low + 0.5
        return "\(formatHours(low))–\(formatHours(high)) hours"
    }

    private static func hoursTextRu(aroundMinutes: Int) -> String {
        let hours = Double(aroundMinutes) / 60.0
        let low = (hours * 2).rounded() / 2
        let high = low + 0.5
        return "\(formatHoursRu(low))–\(formatHoursRu(high)) часам"
    }

    private static func formatHours(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private static func formatHoursRu(_ value: Double) -> String {
        formatHours(value).replacingOccurrences(of: ".", with: ",")
    }
}
