import Foundation

enum CoachFeelingCopy {

    static func bi(_ english: String, _ russian: String, chinese: String? = nil) -> CoachBilingualText {
        let resolvedChinese = chinese
            ?? CoachChineseOverrides.resolved(english: english)
            ?? english
        return .en(english, russian, chinese: resolvedChinese)
    }

    static func resolve(_ text: CoachBilingualText) -> String {
        text.resolved()
    }

    struct ComparisonCopy {
        let headline: CoachBilingualText
        let explanation: CoachBilingualText
        let facts: [CoachBilingualText]
        let details: [CoachBilingualText]
    }

    static func comparison(
        feeling: CoachFeelingKind,
        clarification: CoachFeelingClarification?,
        outcome: CoachFeelingComparisonKind,
        evidence: CoachFeelingEvidenceSnapshot
    ) -> ComparisonCopy {
        var facts: [CoachBilingualText] = []
        var details: [CoachBilingualText] = []

        if let sleep = evidence.sleepMinutes, let baseline = evidence.sleepBaselineMinutes {
            let sleepText = AskCoachCopy.sleepHours(from: sleep)
            let baselineText = AskCoachCopy.sleepHours(from: baseline)
            let delta = sleep - baseline
            if delta <= -CoachFeelingEvidenceRules.tiredSleepShortfallMinutes {
                facts.append(
                    bi(
                        "Recent sleep \(sleepText.english) — about \(abs(delta))m shorter than your recent baseline (\(baselineText.english)). Shorter sleep may be one contributor.",
                        "Недавний сон \(sleepText.russian) — примерно на \(abs(delta))м короче вашего недавнего базового (\(baselineText.russian)). Более короткий сон может быть одним из факторов."
                    )
                )
            } else if abs(delta) <= CoachFeelingEvidenceRules.sleepNearBaselineMinutes {
                facts.append(
                    bi(
                        "Recent sleep \(sleepText.english) looks typical for you (baseline \(baselineText.english)).",
                        "Недавний сон \(sleepText.russian) выглядит типичным для вас (базовый \(baselineText.russian))."
                    )
                )
            } else if delta > 0 {
                facts.append(
                    bi(
                        "Recent sleep \(sleepText.english) is a bit longer than your baseline (\(baselineText.english)).",
                        "Недавний сон \(sleepText.russian) чуть длиннее базового (\(baselineText.russian))."
                    )
                )
            } else {
                facts.append(
                    bi(
                        "Recent sleep \(sleepText.english) vs baseline \(baselineText.english).",
                        "Недавний сон \(sleepText.russian) vs базовый \(baselineText.russian)."
                    )
                )
            }
            if let dayKey = evidence.sleepDayKey {
                details.append(bi("Sleep source day: \(dayKey)", "День сна: \(dayKey)"))
            }
            details.append(
                bi(
                    "Sleep baseline from \(evidence.sleepSampleCount) nights",
                    "Базовый сон по \(evidence.sleepSampleCount) ночам"
                )
            )
        } else if evidence.sleepIsStale {
            details.append(
                bi(
                    "Most recent sleep looks too old to treat as current.",
                    "Самый свежий сон слишком давний, чтобы считать его актуальным."
                )
            )
        } else if evidence.sleepSampleCount < CoachFeelingEvidenceRules.minimumSleepBaselineSamples {
            details.append(
                bi(
                    "Sleep baseline needs \(CoachFeelingEvidenceRules.minimumSleepBaselineSamples)+ nights (have \(evidence.sleepSampleCount)).",
                    "Для базового сна нужно \(CoachFeelingEvidenceRules.minimumSleepBaselineSamples)+ ночей (есть \(evidence.sleepSampleCount))."
                )
            )
        }

        if let recovery = evidence.recoveryPercent, let baseline = evidence.recoveryBaselinePercent {
            let delta = recovery - baseline
            if delta <= -CoachFeelingEvidenceRules.tiredRecoveryShortfallPoints {
                facts.append(
                    bi(
                        "Recovery \(recovery)% — about \(abs(delta)) points below your recent baseline (\(baseline)%). This measurement is softer than usual for you.",
                        "Восстановление \(recovery)% — примерно на \(abs(delta)) пунктов ниже недавнего базового (\(baseline)%). Этот показатель мягче обычного для вас."
                    )
                )
            } else if abs(delta) <= CoachFeelingEvidenceRules.recoveryNearBaselinePoints {
                facts.append(
                    bi(
                        "Recovery \(recovery)% looks typical for you (baseline \(baseline)%).",
                        "Восстановление \(recovery)% выглядит типичным для вас (базовый \(baseline)%)."
                    )
                )
            } else {
                facts.append(
                    bi(
                        "Recovery \(recovery)% vs baseline \(baseline)%.",
                        "Восстановление \(recovery)% vs базовый \(baseline)%."
                    )
                )
            }
            if let dayKey = evidence.recoveryDayKey {
                details.append(bi("Recovery source day: \(dayKey)", "День восстановления: \(dayKey)"))
            }
            details.append(
                bi(
                    "Recovery baseline from \(evidence.recoverySampleCount) days",
                    "Базовое восстановление по \(evidence.recoverySampleCount) дням"
                )
            )
        }

        if evidence.recentActivityCount > 0 {
            details.append(
                bi(
                    "\(evidence.recentActivityCount) logged activities in the last \(evidence.activityWindowHours)h (context only — not a load score).",
                    "\(evidence.recentActivityCount) записанных активностей за \(evidence.activityWindowHours)ч (только контекст — не оценка нагрузки)."
                )
            )
        }

        let headline: CoachBilingualText
        let explanation: CoachBilingualText

        switch outcome {
        case .supporting:
            headline = bi(
                "Your data shows similar signals.",
                "Данные показывают похожие сигналы."
            )
            explanation = bi(
                "Here’s what lines up with feeling \(feeling.bilingualTitle.english.lowercased()) — without treating this as a diagnosis.",
                "Вот что согласуется с ощущением «\(feeling.bilingualTitle.russian.lowercased())» — без постановки диагноза."
            )

        case .mixed:
            headline = bi(
                "Your numbers don’t fully explain how you feel.",
                "Цифры не полностью объясняют, как вы себя чувствуете."
            )
            explanation = bi(
                "Your reported feeling still stands. Metrics can miss stress, illness, travel, or simply a quiet day — we don’t have enough to identify a pattern from this alone.",
                "Ваше ощущение остаётся важным. Метрики могут не учитывать стресс, недомогание, поездки или просто тихий день — одного сравнения мало, чтобы увидеть устойчивый паттерн."
            )

        case .insufficient:
            headline = bi(
                "There isn’t enough recent data to compare yet.",
                "Пока недостаточно свежих данных для сравнения."
            )
            var missing: [String] = []
            var missingRU: [String] = []
            if evidence.sleepMinutes == nil {
                missing.append("recent sleep")
                missingRU.append("недавний сон")
            }
            if evidence.recoveryPercent == nil {
                missing.append("recovery score")
                missingRU.append("показатель восстановления")
            }
            if evidence.sleepBaselineMinutes == nil, evidence.sleepMinutes != nil {
                missing.append("sleep baseline")
                missingRU.append("базовый сон")
            }
            if evidence.recoveryBaselinePercent == nil, evidence.recoveryPercent != nil {
                missing.append("recovery baseline")
                missingRU.append("базовое восстановление")
            }
            let missingEN = missing.isEmpty ? "sleep or recovery" : missing.joined(separator: " and ")
            let missingRUJoined = missingRU.isEmpty ? "сон или восстановление" : missingRU.joined(separator: " и ")
            explanation = bi(
                "We still hear that you feel \(feeling.bilingualTitle.english.lowercased()). Missing for a fair comparison: \(missingEN).",
                "Мы всё равно учитываем, что вы чувствуете себя «\(feeling.bilingualTitle.russian.lowercased())». Для сравнения не хватает: \(missingRUJoined)."
            )
        }

        if let clarification {
            details.insert(
                bi(
                    "You noted: \(clarification.bilingualTitle.english).",
                    "Вы отметили: \(clarification.bilingualTitle.russian)."
                ),
                at: 0
            )
        }

        return ComparisonCopy(
            headline: headline,
            explanation: explanation,
            facts: facts,
            details: details
        )
    }

    static func tryTodaySuggestion(
        feeling: CoachFeelingKind,
        outcome: CoachFeelingComparisonKind,
        evidence: CoachFeelingEvidenceSnapshot
    ) -> (headline: CoachBilingualText, explanation: CoachBilingualText, facts: [CoachBilingualText]) {
        let headline = bi(
            "A gentle option — only if it fits today.",
            "Мягкий вариант — только если подходит сегодня."
        )

        switch (feeling, outcome) {
        case (.tired, .supporting), (.low, .supporting):
            let sleepShort = (evidence.sleepMinutes != nil && evidence.sleepBaselineMinutes != nil)
                && (evidence.sleepMinutes! - evidence.sleepBaselineMinutes!
                    <= -CoachFeelingEvidenceRules.tiredSleepShortfallMinutes)
            if sleepShort {
                return (
                    headline,
                    bi(
                        "If you can, protect a slightly earlier wind-down tonight. This is optional — your Plan isn’t changed.",
                        "Если получится, чуть раньше начните вечернее затихание. Это по желанию — План не меняется."
                    ),
                    [
                        bi(
                            "Shorter sleep may be one contributor; we’re not claiming it caused how you feel.",
                            "Более короткий сон может быть одним из факторов; мы не утверждаем, что он вызвал это ощущение."
                        )
                    ]
                )
            }
            return (
                headline,
                bi(
                    "Keep today lighter if you can, and notice how you feel after rest — without forcing a training change.",
                    "Если можно, сделайте день полегче и просто отметьте самочувствие после отдыха — без принудительной смены тренировок."
                ),
                []
            )

        case (.tired, .mixed), (.tired, .insufficient), (.low, .mixed), (.low, .insufficient):
            return (
                headline,
                bi(
                    "Trust the feeling even when numbers are unclear. A short break or easier movement is enough for today.",
                    "Доверяйте ощущению, даже если цифры неясны. Короткого перерыва или более лёгкого движения на сегодня достаточно."
                ),
                []
            )

        case (.energized, _):
            return (
                headline,
                bi(
                    "If energy feels solid, keep today’s plan steady rather than adding extra load on a good feeling alone.",
                    "Если энергия ощущается стабильной, лучше держать сегодняшний план, а не добавлять нагрузку только из-за хорошего самочувствия."
                ),
                []
            )

        case (.okay, _):
            return (
                headline,
                bi(
                    "Staying with your existing plan is a reasonable default when you feel okay.",
                    "Если самочувствие нормальное, разумно просто следовать текущему плану."
                ),
                []
            )
        }
    }

    static func shortSummary(for checkIn: CoachFeelingCheckIn) -> CoachBilingualText {
        switch checkIn.outcome {
        case .supporting:
            return bi("Similar signals in your data", "Похожие сигналы в данных")
        case .mixed:
            return bi("Numbers don’t fully explain it", "Цифры объясняют не полностью")
        case .insufficient:
            return bi("Not enough recent data yet", "Пока мало свежих данных")
        }
    }

    static func formatCheckInTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, HH:mm")
        return formatter.string(from: date)
    }
}
