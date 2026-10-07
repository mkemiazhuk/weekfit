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
            return CoachState.localized(english: "Sleep", russian: "Сон", chinese: "睡眠")
        case .training:
            return CoachState.localized(english: "Training", russian: "Тренировки", chinese: "训练")
        case .nutrition:
            return CoachState.localized(english: "Nutrition", russian: "Питание", chinese: "营养")
        case .timing:
            return CoachState.localized(english: "Timing", russian: "Тайминг", chinese: "时机")
        }
    }

    static var noticedEyebrow: String {
        CoachState.localized(
            english: "I noticed something",
            russian: "Я кое-что заметил",
            chinese: "我注意到一件事"
        )
    }

    static var gotItAction: String {
        CoachState.localized(
            english: "Got it",
            russian: "Понятно",
            chinese: "知道了"
        )
    }

    // MARK: - Title

    private static func title(for beliefID: CoachBeliefID) -> String {
        switch beliefID {
        case .sleepConsistencyRecovery:
            return CoachState.localized(
                english: "Consistent bedtime",
                russian: "Стабильное время сна",
                chinese: "规律就寝"
            )
        case .sleepDurationRecovery:
            return CoachState.localized(
                english: "Sleep duration",
                russian: "Длительность сна",
                chinese: "睡眠时长"
            )
        case .lateBedtimeRecovery:
            return CoachState.localized(
                english: "Later bedtimes",
                russian: "Поздний отбой",
                chinese: "较晚就寝"
            )
        case .heavyLoadRecoveryLag:
            return CoachState.localized(
                english: "Hard training recovery",
                russian: "Восстановление после тяжёлых дней",
                chinese: "高强度训练后的恢复"
            )
        case .recoveryAfterRestDay:
            return CoachState.localized(
                english: "Lighter days help",
                russian: "Лёгкие дни помогают",
                chinese: "轻松日有帮助"
            )
        case .consecutiveHardDaysFatigue:
            return CoachState.localized(
                english: "Stacked hard days",
                russian: "Тяжёлые дни подряд",
                chinese: "连续高强度日"
            )
        case .underfuelingRecovery:
            return CoachState.localized(
                english: "Underfueling",
                russian: "Недобор энергии",
                chinese: "能量摄入不足"
            )
        case .proteinTrainingDayRecovery:
            return CoachState.localized(
                english: "Protein on training days",
                russian: "Белок в тренировочные дни",
                chinese: "训练日的蛋白质"
            )
        case .postWorkoutProteinRecovery:
            return CoachState.localized(
                english: "Protein after workouts",
                russian: "Белок после тренировок",
                chinese: "训练后的蛋白质"
            )
        case .hardTrainingLowRecoveryCost:
            return CoachState.localized(
                english: "Training while depleted",
                russian: "Тренировки без восстановления",
                chinese: "恢复不足时训练"
            )
        case .carbsTrainingDayRecovery:
            return CoachState.localized(
                english: "Carbs on training days",
                russian: "Углеводы в тренировочные дни",
                chinese: "训练日的碳水"
            )
        case .lateHardTrainingSleep:
            return CoachState.localized(
                english: "Late hard sessions",
                russian: "Поздние тяжёлые тренировки",
                chinese: "较晚的高强度训练"
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
                russian: "Восстановление на следующий день обычно выше, когда вы ложитесь спать примерно в одно и то же время.",
                chinese: "就寝时间保持规律时，第二天的恢复通常更好。"
            )
        case .sleepDurationRecovery:
            if let threshold = SleepDurationBeliefEvaluator.analyze(observations: observations)?.sufficientSleepThresholdMinutes {
                let hoursText = formatHoursRange(aroundMinutes: threshold)
                let hoursTextZh = formatHoursRangeZh(aroundMinutes: threshold)
                return CoachState.localized(
                    english: "When your sleep gets closer to about \(hoursText), your recovery usually comes back stronger.",
                    russian: "Когда сон приближается к \(hoursTextRu(aroundMinutes: threshold)), восстановление обычно возвращается заметно сильнее.",
                    chinese: "当睡眠接近大约 \(hoursTextZh) 时，恢复通常会明显回升。"
                )
            }
            return CoachState.localized(
                english: "When your sleep gets closer to the amount that works for you, your recovery usually comes back stronger.",
                russian: "Когда сон приближается к длительности, которая вам подходит, восстановление обычно возвращается заметно сильнее.",
                chinese: "当睡眠接近适合你的时长时，恢复通常会明显回升。"
            )
        case .lateBedtimeRecovery:
            return CoachState.localized(
                english: "When you go to bed later than usual, your recovery the next morning tends to be lower.",
                russian: "Когда вы ложитесь позже обычного, восстановление утром обычно ниже.",
                chinese: "比平时更晚睡时，第二天早上的恢复往往会更低。"
            )
        case .heavyLoadRecoveryLag:
            return CoachState.localized(
                english: "After your harder training days, your recovery often needs a day or two to come back.",
                russian: "После тяжёлых тренировочных дней восстановлению часто нужен ещё день-два, чтобы вернуться.",
                chinese: "高强度训练日后，恢复往往还需要一两天才能回来。"
            )
        case .recoveryAfterRestDay:
            return CoachState.localized(
                english: "A lighter day after heavier work usually helps your recovery come back stronger.",
                russian: "Лёгкий день после более тяжёлой нагрузки обычно помогает восстановлению вернуться сильнее.",
                chinese: "在较重负荷后安排轻松一天，通常有助于恢复更快回升。"
            )
        case .consecutiveHardDaysFatigue:
            return CoachState.localized(
                english: "When harder training days stack back to back, your recovery usually dips more noticeably.",
                russian: "Когда тяжёлые тренировочные дни идут подряд, восстановление обычно проседает заметнее.",
                chinese: "高强度训练日连续叠加时，恢复通常会更明显下降。"
            )
        case .underfuelingRecovery:
            return CoachState.localized(
                english: "When you finish days significantly underfueled, your recovery often comes back weaker.",
                russian: "Когда день заканчивается с заметным недобором энергии, восстановление чаще возвращается слабее.",
                chinese: "一天结束时能量明显不足，恢复往往会更弱。"
            )
        case .proteinTrainingDayRecovery:
            if let evaluation = ProteinTrainingDayRecoveryBeliefEvaluator.analyze(observations: observations),
               evaluation.recoveryDelta > 0 {
                let low = evaluation.lowProteinMedianGrams + 10
                let high = evaluation.highProteinMedianGrams + 10
                return CoachState.localized(
                    english: "On training days around \(low)–\(high) g protein, your next-day recovery tends to come back stronger.",
                    russian: "В тренировочные дни около \(low)–\(high) г белка восстановление на следующий день обычно возвращается сильнее.",
                    chinese: "训练日蛋白质约 \(low)–\(high) 克时，次日恢复通常更好。"
                )
            }
            return CoachState.localized(
                english: "On training days with higher protein, your next-day recovery tends to come back stronger.",
                russian: "В тренировочные дни с более высоким белком восстановление на следующий день обычно возвращается сильнее.",
                chinese: "训练日蛋白质更高时，次日恢复通常更好。"
            )
        case .postWorkoutProteinRecovery:
            if let evaluation = PostWorkoutProteinRecoveryBeliefEvaluator.analyze(observations: observations),
               evaluation.recoveryDelta > 0 {
                let target = max(evaluation.splitThresholdGrams, 30)
                return CoachState.localized(
                    english: "When you get closer to about \(target) g protein soon after harder workouts, next-day recovery tends to look better.",
                    russian: "Когда после более тяжёлых тренировок вы быстрее набираете около \(target) г белка, восстановление на следующий день обычно выглядит лучше.",
                    chinese: "高强度训练后尽快摄入约 \(target) 克蛋白质时，次日恢复通常更好。"
                )
            }
            return CoachState.localized(
                english: "When you get more protein soon after harder workouts, next-day recovery tends to look better.",
                russian: "Когда после более тяжёлых тренировок вы быстрее набираете белок, восстановление на следующий день обычно выглядит лучше.",
                chinese: "高强度训练后尽快补充更多蛋白质时，次日恢复通常更好。"
            )
        case .hardTrainingLowRecoveryCost:
            return CoachState.localized(
                english: "Pushing hard while still poorly recovered tends to cost more on the next day's recovery.",
                russian: "Тяжёлая нагрузка при слабом восстановлении обычно сильнее бьёт по восстановлению на следующий день.",
                chinese: "在恢复仍差时硬推强度，通常会更伤次日恢复。"
            )
        case .carbsTrainingDayRecovery:
            if let evaluation = CarbsTrainingDayRecoveryBeliefEvaluator.analyze(observations: observations),
               evaluation.recoveryDelta > 0 {
                let low = evaluation.lowCarbsMedianGrams + 15
                let high = evaluation.highCarbsMedianGrams + 15
                return CoachState.localized(
                    english: "On harder training days around \(low)–\(high) g carbs, your next-day recovery tends to come back stronger.",
                    russian: "В более тяжёлые тренировочные дни около \(low)–\(high) г углеводов восстановление на следующий день обычно возвращается сильнее.",
                    chinese: "较重训练日碳水约 \(low)–\(high) 克时，次日恢复通常更好。"
                )
            }
            return CoachState.localized(
                english: "On harder training days with higher carbs, your next-day recovery tends to come back stronger.",
                russian: "В более тяжёлые тренировочные дни с более высоким углеводом восстановление на следующий день обычно возвращается сильнее.",
                chinese: "较重训练日碳水更高时，次日恢复通常更好。"
            )
        case .lateHardTrainingSleep:
            if let evaluation = LateHardTrainingSleepBeliefEvaluator.analyze(observations: observations),
               evaluation.sleepDropMinutes > 0 {
                let hour = evaluation.lateThresholdMinutes / 60
                return CoachState.localized(
                    english: "When harder sessions finish after about \(hour):00, the following night's sleep tends to come in shorter.",
                    russian: "Когда более тяжёлые тренировки заканчиваются после \(hour):00, сон следующей ночи обычно получается короче.",
                    chinese: "高强度训练在大约 \(hour):00 之后结束时，当晚睡眠往往会更短。"
                )
            }
            return CoachState.localized(
                english: "When harder sessions finish late, the following night's sleep tends to come in shorter.",
                russian: "Когда более тяжёлые тренировки заканчиваются поздно, сон следующей ночи обычно получается короче.",
                chinese: "高强度训练结束得较晚时，当晚睡眠往往会更短。"
            )
        }
    }

    // MARK: - Proof

    private static func proof(for beliefID: CoachBeliefID) -> String {
        switch beliefID.discoveryFamily {
        case .sleep:
            return CoachState.localized(
                english: "Based on your recent nights.",
                russian: "На основе ваших недавних ночей.",
                chinese: "基于你最近几晚的数据。"
            )
        case .training:
            return CoachState.localized(
                english: "Based on your recent training days.",
                russian: "На основе ваших недавних тренировочных дней.",
                chinese: "基于你最近的训练日。"
            )
        case .nutrition:
            return CoachState.localized(
                english: "Based on your recent nutrition and recovery.",
                russian: "На основе вашего недавнего питания и восстановления.",
                chinese: "基于你最近的营养与恢复。"
            )
        case .timing:
            return CoachState.localized(
                english: "Based on your recent patterns.",
                russian: "На основе ваших недавних паттернов.",
                chinese: "基于你最近的模式。"
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

    private static func formatHoursRangeZh(aroundMinutes: Int) -> String {
        let hours = Double(aroundMinutes) / 60.0
        let low = (hours * 2).rounded() / 2
        let high = low + 0.5
        return "\(formatHours(low))–\(formatHours(high)) 小时"
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
