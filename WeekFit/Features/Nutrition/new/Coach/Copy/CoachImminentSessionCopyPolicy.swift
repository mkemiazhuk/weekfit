import Foundation

/// Concrete pre-session copy when the next activity starts within the shared prep window.
enum CoachImminentSessionCopyPolicy {

    private static let imminentWindowMinutes = CoachActivityWindowPolicy.beforeSessionCopyWindowMinutes

    struct BasePack {
        let assessment: CoachCopySection
        let recommendation: CoachCopySection
        let avoid: CoachCopySection
        let nextAction: CoachCopySection
    }

    struct Teaser {
        let todayMessage: CoachBilingualText
        let coachHeadline: CoachBilingualText
    }

    static func isImminent(_ input: CoachCopyBuildInput) -> Bool {
        guard input.sessionPhase == .pre, input.focusSource == .upcoming else { return false }
        guard let minutes = input.minutesUntilStart, minutes >= 0, minutes <= imminentWindowMinutes else {
            return false
        }
        guard let activity = input.focusActivity else { return false }
        // Never treat unclassified / meal-like focus as a workout prep session.
        guard activity.activityType != .none else { return false }
        return true
    }

    static func basePack(for input: CoachCopyBuildInput, protective: Bool) -> BasePack? {
        guard isImminent(input), let activity = input.focusActivity else { return nil }

        return BasePack(
            assessment: .single(assessment(for: activity, input: input, protective: protective)),
            recommendation: .single(recommendation(for: activity, input: input, protective: protective)),
            avoid: .single(avoid(for: activity, protective: protective)),
            nextAction: .single(nextAction(for: activity, input: input, protective: protective))
        )
    }

    static func teaser(for input: CoachCopyBuildInput, protective: Bool) -> Teaser? {
        guard isImminent(input), let activity = input.focusActivity else { return nil }

        let titleEN = displayTitle(activity, language: .english)
        let titleRU = displayTitle(activity, language: .russian)
        let titleZH = displayTitle(activity, language: .chineseSimplified)
        let minutes = input.minutesUntilStart ?? 0
        let minutesEN = formatMinutesUntil(minutes, language: .english)
        let minutesRU = formatMinutesUntil(minutes, language: .russian)
        let minutesZH = formatMinutesUntil(minutes, language: .chineseSimplified)

        let todayMessage: CoachBilingualText
        if protective {
            todayMessage = CoachBilingualText(
                english: "\(titleEN) \(minutesEN) — start easier than planned.",
                russian: "\(titleRU.capitalized) \(minutesRU) — начните легче плана.",
                chinese: "\(titleZH)\(minutesZH)——比计划更轻松地开始。"
            )
        } else {
            todayMessage = CoachBilingualText(
                english: "\(titleEN) \(minutesEN) — \(activity.formattedStartTime) on the clock.",
                russian: "\(titleRU.capitalized) \(minutesRU) — старт в \(activity.formattedStartTime).",
                chinese: "\(titleZH)\(minutesZH)——\(activity.formattedStartTime) 开始。"
            )
        }

        return Teaser(
            todayMessage: todayMessage,
            coachHeadline: coachHeadline(for: activity.activityType)
        )
    }

    // MARK: - Sections

    private static func assessment(
        for activity: CoachPlannedActivitySummary,
        input: CoachCopyBuildInput,
        protective: Bool
    ) -> CoachBilingualText {
        let titleEN = displayTitle(activity, language: .english)
        let titleRU = displayTitle(activity, language: .russian)
        let titleZH = displayTitle(activity, language: .chineseSimplified)
        let minutesEN = formatMinutesUntil(input.minutesUntilStart ?? 0, language: .english)
        let minutesRU = formatMinutesUntil(input.minutesUntilStart ?? 0, language: .russian)
        let minutesZH = formatMinutesUntil(input.minutesUntilStart ?? 0, language: .chineseSimplified)
        let durationClauseEN = durationClause(minutes: activity.durationMinutes, language: .english)
        let durationClauseRU = durationClause(minutes: activity.durationMinutes, language: .russian)
        let durationClauseZH = durationClause(minutes: activity.durationMinutes, language: .chineseSimplified)

        if protective {
            if input.dayReadiness.sleepIsLow {
                return CoachBilingualText(
                    english: "\(titleEN) \(minutesEN) (\(durationClauseEN)) — short sleep, recovery not full yet.",
                    russian: "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — короткий сон, восстановление пока не полное.",
                    chinese: "\(titleZH)\(minutesZH)（\(durationClauseZH)）——睡眠偏短，恢复尚未到位。"
                )
            }
            if input.dayReadiness.isLowRecovery {
                return CoachBilingualText(
                    english: "\(titleEN) \(minutesEN) (\(durationClauseEN)) — recovery is still lagging.",
                    russian: "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — тело ещё не восстановилось.",
                    chinese: "\(titleZH)\(minutesZH)（\(durationClauseZH)）——恢复仍偏弱。"
                )
            }
            return CoachBilingualText(
                english: "\(titleEN) \(minutesEN) (\(durationClauseEN)) — not fully topped up yet.",
                russian: "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — запас ещё не полный.",
                chinese: "\(titleZH)\(minutesZH)（\(durationClauseZH)）——状态尚未完全蓄满。"
            )
        }

        switch activity.activityType {
        case .hiit:
            return CoachBilingualText(
                english: "\(titleEN) \(minutesEN) (\(durationClauseEN)) — warm up before the first hard interval.",
                russian: "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — разомнитесь до первого жёсткого интервала.",
                chinese: "\(titleZH)\(minutesZH)（\(durationClauseZH)）——先热身，再进入第一个高强度间歇。"
            )
        case .cycling:
            return CoachBilingualText(
                english: "\(titleEN) \(minutesEN) (\(durationClauseEN)) — time to settle pace and legs.",
                russian: "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — пора настроить темп и ноги.",
                chinese: "\(titleZH)\(minutesZH)（\(durationClauseZH)）——先稳住配速与双腿。"
            )
        case .running:
            return CoachBilingualText(
                english: "\(titleEN) \(minutesEN) (\(durationClauseEN)) — dial in effort before the first mile.",
                russian: "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — найдите темп до первого километра.",
                chinese: "\(titleZH)\(minutesZH)（\(durationClauseZH)）——先找好强度，再进入第一公里。"
            )
        case .swimming:
            return CoachBilingualText(
                english: "\(titleEN) \(minutesEN) (\(durationClauseEN)) — settle into a steady stroke early.",
                russian: "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — с первых метров ищите ровный гребок.",
                chinese: "\(titleZH)\(minutesZH)（\(durationClauseZH)）——尽早找到稳定的划水节奏。"
            )
        default:
            return CoachBilingualText(
                english: "\(titleEN) \(minutesEN) (\(durationClauseEN)) — arrive calm, not already chasing.",
                russian: "\(titleRU.capitalized) \(minutesRU) (\(durationClauseRU)) — выходите спокойно, без гонки с порога.",
                chinese: "\(titleZH)\(minutesZH)（\(durationClauseZH)）——平静到位，别一上来就赶。"
            )
        }
    }

    private static func recommendation(
        for activity: CoachPlannedActivitySummary,
        input: CoachCopyBuildInput,
        protective: Bool
    ) -> CoachBilingualText {
        let longSession = isLongSession(activity)

        if protective {
            if longSession {
                return CoachBilingualText(
                    english: "Keep the first hour easy; shorten the session if legs stay heavy.",
                    russian: "Первый час держите легко; сократите объём, если ноги тяжёлые.",
                    chinese: "第一小时保持轻松；若双腿仍沉重，缩短训练。"
                )
            }
            return CoachBilingualText(
                english: "Start lighter than planned and leave room to finish strong.",
                russian: "Начните легче плана — так сил хватит на сильный финиш.",
                chinese: "比计划更轻松地开始，留出余力强势收尾。"
            )
        }

        switch activity.activityType {
        case .hiit:
            if longSession {
                return CoachBilingualText(
                    english: "Ease into the first rounds — quality intervals beat an early blow-up.",
                    russian: "Первые раунды мягче — лучше качественные интервалы, чем ранний срыв.",
                    chinese: "前几轮柔和进入——干净的间歇好过过早崩盘。"
                )
            }
            return CoachBilingualText(
                english: "Open with a short warm-up, then hit intervals clean — not all-out from round one.",
                russian: "Короткая разминка, потом чистые интервалы — не на максимум с первого раунда.",
                chinese: "先短暂热身，再干净地做间歇——别从第一轮就全力。"
            )
        case .cycling:
            if longSession {
                return CoachBilingualText(
                    english: "First hour easy — let breathing and rhythm settle before pushing.",
                    russian: "Первый час легко — дайте дыханию и ритму настроиться до усилия.",
                    chinese: "第一小时轻松——先稳住呼吸与节奏，再加压。"
                )
            }
            return CoachBilingualText(
                english: "Start easy — let cadence and breathing find their place.",
                russian: "Начните легко — пусть каденс и дыхание настроятся сами.",
                chinese: "轻松开始——先让踏频与呼吸到位。"
            )
        case .running:
            if longSession {
                return CoachBilingualText(
                    english: "First hour easy — let breathing and rhythm settle before pushing.",
                    russian: "Первый час легко — дайте дыханию и ритму настроиться до усилия.",
                    chinese: "第一小时轻松——先稳住呼吸与节奏，再加压。"
                )
            }
            return CoachBilingualText(
                english: "Start easy — let breathing and rhythm find their place.",
                russian: "Начните легко — пусть дыхание и ритм настроятся сами.",
                chinese: "轻松开始——先让呼吸与节奏到位。"
            )
        case .swimming:
            return CoachBilingualText(
                english: "Start easy — find a steady stroke before any speed work.",
                russian: "Начните легко — сначала ровный гребок, потом скорость.",
                chinese: "轻松开始——先找到稳定划水，再提速。"
            )
        default:
            if longSession {
                return CoachBilingualText(
                    english: "First block easy — settle in before you push.",
                    russian: "Первый блок легко — сначала войдите в ритм, потом усилие.",
                    chinese: "第一段轻松——先进入节奏，再加压。"
                )
            }
            return CoachBilingualText(
                english: "Start easy — warm up before the hard work.",
                russian: "Начните легко — разомнитесь до основной работы.",
                chinese: "轻松开始——先热身，再进入主课。"
            )
        }
    }

    private static func avoid(
        for activity: CoachPlannedActivitySummary,
        protective: Bool
    ) -> CoachBilingualText {
        switch activity.activityType {
        case .hiit:
            if protective {
                return CoachBilingualText(
                    english: "Don't force every interval to max when recovery is still behind.",
                    russian: "Не делайте каждый интервал на максимум, пока тело ещё не восстановилось.",
                    chinese: "恢复仍不足时，别把每个间歇都顶到极限。"
                )
            }
            return CoachBilingualText(
                english: "Don't open with an all-out interval — earn the intensity.",
                russian: "Не открывайте первым интервалом на максимум — интенсивность нужно заслужить.",
                chinese: "别用全力间歇开场——强度要逐步拿到。"
            )
        case .cycling:
            if protective {
                let durationEN = durationClause(minutes: activity.durationMinutes, language: .english)
                let durationRU = durationClause(minutes: activity.durationMinutes, language: .russian)
                let durationZH = durationClause(minutes: activity.durationMinutes, language: .chineseSimplified)
                return CoachBilingualText(
                    english: "Don't force the full \(durationEN) effort from the first minutes.",
                    russian: "Не форсируйте полный объём (\(durationRU)) с первых минут.",
                    chinese: "别从最初几分钟就硬推完整 \(durationZH) 强度。"
                )
            }
            return CoachBilingualText(
                english: "Don't open with a sprint or heavy gear.",
                russian: "Не стартуйте рывком или тяжёлой передачей.",
                chinese: "别用冲刺或很重的齿比开场。"
            )
        case .running, .swimming:
            if protective {
                let durationEN = durationClause(minutes: activity.durationMinutes, language: .english)
                let durationRU = durationClause(minutes: activity.durationMinutes, language: .russian)
                let durationZH = durationClause(minutes: activity.durationMinutes, language: .chineseSimplified)
                return CoachBilingualText(
                    english: "Don't force the full \(durationEN) effort from the first minutes.",
                    russian: "Не форсируйте полный объём (\(durationRU)) с первых минут.",
                    chinese: "别从最初几分钟就硬推完整 \(durationZH) 强度。"
                )
            }
            return CoachBilingualText(
                english: "Don't open with a sprint from the first minutes.",
                russian: "Не стартуйте рывком с первых минут.",
                chinese: "别从最初几分钟就冲刺开场。"
            )
        case .tennis, .squash:
            return CoachBilingualText(
                english: "Don't spend energy before the first point matters.",
                russian: "Не тратьте силы до первого важного розыгрыша.",
                chinese: "别在第一分真正重要前就把体力耗掉。"
            )
        default:
            return CoachBilingualText(
                english: "Don't race the clock from the first set.",
                russian: "Не гонитесь с первых же подходов.",
                chinese: "别从第一组就开始赶时间。"
            )
        }
    }

    private static func nextAction(
        for activity: CoachPlannedActivitySummary,
        input: CoachCopyBuildInput,
        protective: Bool
    ) -> CoachBilingualText {
        let titleEN = displayTitle(activity, language: .english)
        let titleRU = displayTitle(activity, language: .russian)
        let titleZH = displayTitle(activity, language: .chineseSimplified)
        let time = activity.formattedStartTime

        if isLongSession(activity) {
            return CoachBilingualText(
                english: "Water and a snack, 10-minute warmup — \(titleEN) at \(time).",
                russian: "Вода и перекус, 10 минут разминки — \(titleRU) в \(time).",
                chinese: "水与加餐，热身 10 分钟——\(titleZH) 于 \(time)。"
            )
        }

        switch activity.activityType {
        case .cycling, .running, .swimming, .hiit:
            return CoachBilingualText(
                english: "10-minute warmup — \(titleEN) at \(time).",
                russian: "10 минут разминки — \(titleRU) в \(time).",
                chinese: "热身 10 分钟——\(titleZH) 于 \(time)。"
            )
        case .tennis, .squash:
            return CoachBilingualText(
                english: "15-minute warmup — \(titleEN) at \(time).",
                russian: "15 минут разминки — \(titleRU) в \(time).",
                chinese: "热身 15 分钟——\(titleZH) 于 \(time)。"
            )
        default:
            return CoachBilingualText(
                english: "Light first sets — \(titleEN) at \(time).",
                russian: "Первые подходы легко — \(titleRU) в \(time).",
                chinese: "前几组轻松——\(titleZH) 于 \(time)。"
            )
        }
    }

    // MARK: - Formatting

    private static func displayTitle(
        _ activity: CoachPlannedActivitySummary,
        language: AppLanguage
    ) -> String {
        let trimmed = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return activityTypeLabel(activity.activityType, language: language)
        }
        return CoachWorkoutTitleLocalization.displayTitle(trimmed, language: language)
    }

    private static func activityTypeLabel(_ type: CoachActivityType, language: AppLanguage) -> String {
        let english: String
        let russian: String
        let chinese: String
        switch type {
        case .cycling:
            (english, russian, chinese) = ("ride", "велосессия", "骑行")
        case .running:
            (english, russian, chinese) = ("run", "пробежка", "跑步")
        case .swimming:
            (english, russian, chinese) = ("swim", "заплыв", "游泳")
        case .hiit:
            return "HIIT"
        case .tennis:
            (english, russian, chinese) = ("tennis", "теннис", "网球")
        case .squash:
            (english, russian, chinese) = ("squash", "сквош", "壁球")
        case .walk:
            (english, russian, chinese) = ("walk", "прогулка", "步行")
        default:
            (english, russian, chinese) = ("session", "тренировка", "训练")
        }
        switch language {
        case .russian: return russian
        case .chineseSimplified: return chinese
        case .english: return english
        }
    }

    private static func coachHeadline(for type: CoachActivityType) -> CoachBilingualText {
        switch type {
        case .cycling:
            return CoachBilingualText(english: "Before the ride", russian: "Перед заездом", chinese: "骑行前")
        case .running:
            return CoachBilingualText(english: "Before the run", russian: "Перед пробежкой", chinese: "跑步前")
        case .swimming:
            return CoachBilingualText(english: "Before the swim", russian: "Перед плаванием", chinese: "游泳前")
        case .hiit:
            return CoachBilingualText(english: "Before HIIT", russian: "Перед HIIT", chinese: "HIIT 前")
        case .tennis, .squash:
            return CoachBilingualText(english: "Before the match", russian: "Перед игрой", chinese: "比赛前")
        default:
            return CoachBilingualText(english: "Before the session", russian: "Перед тренировкой", chinese: "训练前")
        }
    }

    private static func formatMinutesUntil(_ minutes: Int, language: AppLanguage) -> String {
        switch language {
        case .russian:
            return "через \(minutes) мин"
        case .chineseSimplified:
            return "还有 \(minutes) 分钟"
        case .english:
            return "in \(minutes) min"
        }
    }

    private static func durationClause(minutes: Int, language: AppLanguage) -> String {
        "~\(durationHoursLabel(minutes, language: language))"
    }

    private static func durationHoursLabel(_ minutes: Int, language: AppLanguage) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        switch language {
        case .russian:
            if remainder == 0 { return "\(hours) ч" }
            if remainder == 30 { return "\(hours),5 ч" }
            return "\(hours) ч \(remainder) мин"
        case .chineseSimplified:
            if remainder == 0 { return "\(hours) 小时" }
            if remainder == 30 { return "\(hours).5 小时" }
            return "\(hours) 小时 \(remainder) 分钟"
        case .english:
            if remainder == 0 { return "\(hours) h" }
            if remainder == 30 { return "\(hours).5 h" }
            return "\(hours) h \(remainder) min"
        }
    }

    private static func isLongSession(_ activity: CoachPlannedActivitySummary) -> Bool {
        activity.durationMinutes >= 90
    }
}
