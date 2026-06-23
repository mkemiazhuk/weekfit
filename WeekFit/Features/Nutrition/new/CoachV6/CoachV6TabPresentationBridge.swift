import Foundation
import SwiftUI

enum CoachV6TabPresentationBridge {

    struct Result {
        let today: CoachTodayPresentation
        let coach: CoachScreenPresentation
        let ui: CoachV6UIPresentation
    }

    /// Returns V6 tab presentations when `copyPack` exists; otherwise `nil` → V5 fallback.
    static func build(from engineResult: CoachV6Engine.Result) -> Result? {
        guard let pack = engineResult.copyPack else { return nil }

        let ui = uiPresentation(from: engineResult, pack: pack)
        return Result(
            today: todayPresentation(from: ui),
            coach: coachPresentation(from: engineResult, pack: pack, ui: ui),
            ui: ui
        )
    }

    // MARK: - UI model

    private static func uiPresentation(
        from engineResult: CoachV6Engine.Result,
        pack: CoachV6CopyPack
    ) -> CoachV6UIPresentation {
        let insight = engineResult.todayInsight
        let assessment = localizedText(pack.assessment)
        let recommendation = localizedText(pack.recommendation)
        let avoid = localizedText(pack.avoid)
        let nextAction = localizedText(pack.nextAction)
        let supportingSignals = pack.supportingSignals.lines.map(localizedText)
        let warningMessage = pack.warningLayer.map { localizedText($0.message) }

        return CoachV6UIPresentation(
            scenario: pack.scenario,
            assessment: assessment,
            recommendation: recommendation,
            avoid: avoid,
            nextAction: nextAction,
            supportingSignals: supportingSignals,
            warningMessage: warningMessage,
            warningAlert: pack.warningLayer?.alert,
            semanticColor: insight.semanticColor,
            alertSeverity: insight.alertSeverity,
            icon: insight.icon,
            urgencyLevel: insight.urgencyLevel,
            statusLabel: statusLabel(for: insight),
            coachTitle: coachHeadline(
                scenario: pack.scenario,
                activityType: engineResult.modifiers.activityType,
                stackedDayActiveRisk: engineResult.modifiers.stackedDayActiveRisk
            ),
            todayTitle: todayTeaserTitle(
                scenario: pack.scenario,
                assessment: assessment,
                engineResult: engineResult
            ),
            todayMessage: todayTeaserMessage(
                scenario: pack.scenario,
                pack: pack,
                engineResult: engineResult
            )
        )
    }

    private static func todayTeaserTitle(
        scenario: CoachV6ScenarioKey,
        assessment: String,
        engineResult: CoachV6Engine.Result
    ) -> String {
        let ru = WeekFitCurrentLocale().identifier.hasPrefix("ru")
        if engineResult.modifiers.stackedDayActiveRisk {
            return singleLineTitle(ru ? "Нагрузка на пределе" : "Too much already", maxLength: ru ? 22 : 26)
        }

        let title: String
        switch scenario {
        case .tomorrowProtection:
            title = ru ? "Сегодня уже достаточно" : "Protect your energy"
        case .protectTomorrowFresh:
            title = ru ? "Сохраните запас на завтра" : "Save it for tomorrow"
        case .recoveryAfterHeavyYesterday:
            title = ru ? "День восстановления" : "Recovery day"
        case .lowRecoveryPrep:
            title = ru ? "Проверьте готовность" : "Check readiness first"
        case .morningReadiness:
            title = ru ? "С чего начать" : "Set your pace"
        case .stableDay:
            title = ru ? "Спокойный день" : "Steady day"
        case .duringEndurance:
            switch engineResult.modifiers.activityType {
            case .running:
                title = ru ? "На пробежке" : "On the run"
            case .cycling:
                title = ru ? "На заезде" : "On the ride"
            default:
                title = ru ? "В тренировке" : "In session"
            }
        case .walkAfterHeavyLoad:
            title = ru ? "Прогулка после нагрузки" : "Recovery walk"
        case .activeEndurance:
            title = activeEnduranceTitle(activityType: engineResult.modifiers.activityType, ru: ru)
        case .duringRacket:
            title = ru ? "В игре" : "In the match"
        case .duringStrength:
            title = ru ? "Силовая идёт" : "Lifting now"
        case .duringRecovery:
            title = ru ? "Восстановление" : "Recovery time"
        case .postEnduranceImmediate:
            title = ru ? "Заезд завершён" : "Ride done"
        case .postRacketImmediate:
            title = ru ? "Игра позади" : "Match done"
        case .postStrengthImmediate:
            title = ru ? "Последний подход" : "Last set done"
        case .postRecoveryImmediate:
            title = ru ? "Хорошая работа" : "Nice work"
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled:
            title = ru ? "Восстанавливаемся" : "Recovering now"
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            title = ru ? "Вечер после нагрузки" : "Evening recovery"
        case .walkLightDay:
            title = ru ? "Лёгкая прогулка" : "Easy walk"
        case .walkEveningWindDown:
            title = ru ? "Вечерняя прогулка" : "Evening walk"
        case .walkRecoveryAction:
            title = ru ? "Прогулка для ног" : "Leg flush walk"
        case .activeRacket:
            title = ru ? "Игра скоро" : "Match soon"
        case .activeStrength:
            title = ru ? "Силовая впереди" : "Strength next"
        case .activeRecovery:
            title = ru ? "Время восстановить" : "Recovery ahead"
        case .saunaPreparation:
            title = ru ? "Перед баней" : "Before sauna"
        case .saunaActive:
            title = ru ? "В бане" : "In sauna"
        case .saunaRecovery:
            title = ru ? "После жара" : "After heat"
        default:
            title = assessment
        }
        return singleLineTitle(title, maxLength: ru ? 22 : 26)
    }

    private static func activeEnduranceTitle(activityType: CoachV6ActivityType, ru: Bool) -> String {
        switch activityType {
        case .cycling:
            return ru ? "Готовимся к заезду" : "Preparing to ride"
        case .running:
            return ru ? "Готовимся к бегу" : "Preparing to run"
        default:
            return ru ? "Перед тренировкой" : "Before session"
        }
    }

    /// Today card title must stay on one line — hard cap before UI truncation.
    private static func singleLineTitle(_ text: String, maxLength: Int) -> String {
        conciseLine(text.trimmingCharacters(in: .whitespacesAndNewlines), maxLength: maxLength)
    }

    private static func todayTeaserMessage(
        scenario: CoachV6ScenarioKey,
        pack: CoachV6CopyPack,
        engineResult: CoachV6Engine.Result
    ) -> String {
        if engineResult.modifiers.stackedDayActiveRisk {
            return localized(
                english: "Best to stop now.",
                russian: "Лучше закончить на этом."
            )
        }

        switch scenario {
        case .tomorrowProtection:
            if CoachV6CopyNutritionTiming.isWindDown(engineResult.context.timeOfDay) {
                return localized(
                    english: "Wind down — sleep is the priority.",
                    russian: "Сбавьте обороты — сейчас важнее сон."
                )
            }
            return localized(
                english: "Keep the evening easy.",
                russian: "Остаток дня спокойный."
            )
        case .protectTomorrowFresh:
            return localized(
                english: "Good recovery — spend today with tomorrow in mind.",
                russian: "Восстановление хорошее — берегите силы на завтра."
            )
        case .recoveryAfterHeavyYesterday:
            return localized(
                english: "Yesterday still counts — go easier today.",
                russian: "Вчера ещё в теле — сегодня мягче."
            )
        case .lowRecoveryPrep:
            return localized(
                english: "Start lighter than the plan says.",
                russian: "Начните легче, чем в плане."
            )
        case .morningReadiness:
            return localized(
                english: "Lead with how you feel.",
                russian: "Слушайте тело, не только календарь."
            )
        case .stableDay:
            return localized(
                english: "Small steps beat a late catch-up.",
                russian: "Маленькие шаги лучше, чем догонять вечером."
            )
        case .duringEndurance:
            return localized(
                english: "Hold effort flat.",
                russian: "Держите темп ровным."
            )
        case .walkAfterHeavyLoad:
            return localized(
                english: "Slow down — nothing to prove.",
                russian: "Никуда не спешите — просто прогулка."
            )
        case .activeEndurance:
            return localized(
                english: "Set your pace — don't chase from the gun.",
                russian: "Настройте темп — не гонитесь с порога."
            )
        case .activeRacket:
            return localized(
                english: "Warm up — first games under control.",
                russian: "Разогрейтесь — первые геймы спокойно."
            )
        case .activeStrength:
            return localized(
                english: "First sets light — form over weight.",
                russian: "Первые подходы легко — форма важнее."
            )
        case .activeRecovery:
            return localized(
                english: "Soft from minute one — no pressure.",
                russian: "Мягко с первой минуты — без давления."
            )
        case .duringRacket:
            return localized(
                english: "Reset between points.",
                russian: "Между очками успевайте сброс."
            )
        case .duringStrength:
            return localized(
                english: "Form beats rushed reps.",
                russian: "Форма важнее торопливых повторов."
            )
        case .duringRecovery:
            return localized(
                english: "Stay soft — nothing to push.",
                russian: "Мягко — тут нечего выжимать."
            )
        case .postEnduranceImmediate:
            return localized(
                english: "Cooldown first, then refuel.",
                russian: "Сначала заминка — потом еда и вода."
            )
        case .postRacketImmediate:
            return localized(
                english: "Walk the court off — let pulse settle.",
                russian: "Пройдитесь по корту — пульс сам снизится."
            )
        case .postStrengthImmediate:
            return localized(
                english: "Let muscles cool — then protein and water.",
                russian: "Дайте мышцам остыть — потом белок и вода."
            )
        case .postRecoveryImmediate:
            return localized(
                english: "Stay quiet a few more minutes.",
                russian: "Побудьте в тишине ещё несколько минут."
            )
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled:
            return localized(
                english: "Keep the next hour unhurried.",
                russian: "Следующий час без спешки."
            )
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            if CoachV6CopyNutritionTiming.isWindDown(engineResult.context.timeOfDay) {
                return localized(
                    english: "Wind down — sleep is the work.",
                    russian: "Сбавьте обороты — сон важнее."
                )
            }
            return localized(
                english: "Keep the evening easy.",
                russian: "Вечер лёгкий — без лишней нагрузки."
            )
        case .walkLightDay:
            return localized(
                english: "Easy pace — no goal to hit.",
                russian: "Лёгкий темп — без цели."
            )
        case .walkEveningWindDown:
            return localized(
                english: "Slow pace before bed.",
                russian: "Медленный темп перед сном."
            )
        case .walkRecoveryAction:
            return localized(
                english: "Easy steps to flush the legs.",
                russian: "Лёгкие шаги — разогнать ноги."
            )
        case .saunaPreparation:
            return localized(
                english: "Hydrate before the heat.",
                russian: "Выпейте воды перед жаром."
            )
        case .saunaActive:
            return localized(
                english: "Short rounds, cool breaks.",
                russian: "Короткие заходы — паузы на прохладу."
            )
        case .saunaRecovery:
            return localized(
                english: "Cool down slowly.",
                russian: "Остывайте медленно."
            )
        default:
            return conciseLine(localizedText(pack.recommendation), maxLength: 72)
        }
    }

    // MARK: - V5 presentation adapters

    private static func todayPresentation(from ui: CoachV6UIPresentation) -> CoachTodayPresentation {
        CoachTodayPresentation(
            intent: .statusAction,
            statusLabel: ui.statusLabel,
            title: ui.todayTitle,
            message: ui.todayMessage,
            icon: ui.icon,
            color: ui.semanticColor.uiColor
        )
    }

    private static func coachPresentation(
        from engineResult: CoachV6Engine.Result,
        pack: CoachV6CopyPack,
        ui: CoachV6UIPresentation
    ) -> CoachScreenPresentation {
        let whyRows = supportingWhyRows(from: engineResult, pack: pack, semanticColor: ui.semanticColor)

        return CoachScreenPresentation(
            intent: .interpretation,
            stateLabel: ui.statusLabel,
            title: ui.coachTitle,
            message: ui.assessment,
            recommendation: ui.recommendation,
            icon: ui.icon,
            color: ui.semanticColor.uiColor,
            contextChip: nil,
            whyRows: whyRows,
            supportActions: [],
            avoidNotes: ui.avoid.isEmpty ? [] : [ui.avoid]
        )
    }

    private static func supportingWhyRows(
        from engineResult: CoachV6Engine.Result,
        pack: CoachV6CopyPack,
        semanticColor: CoachV6SemanticColor
    ) -> [CoachPresentationWhyRow] {
        let input = CoachV6CopyBuildInput.from(result: engineResult)
        let localizedLines = pack.supportingSignals.lines.map(localizedText)
        var rows: [CoachPresentationWhyRow] = []
        var index = 0

        if input.modifiers.hydrationBehind, input.safetyAlert != .hydrationCritical, index < localizedLines.count {
            rows.append(CoachPresentationWhyRow(
                title: localizedLines[index],
                icon: "drop.fill",
                color: CoachPalette.hydration
            ))
            index += 1
        }

        if input.modifiers.fuelBehind, input.safetyAlert != .fuelCritical, index < localizedLines.count {
            rows.append(CoachPresentationWhyRow(
                title: localizedLines[index],
                icon: "fork.knife",
                color: CoachPalette.fueling
            ))
            index += 1
        }

        if shouldMentionDayLoadInWhyRows(input), index < localizedLines.count {
            rows.append(CoachPresentationWhyRow(
                title: localizedLines[index],
                icon: "chart.bar.fill",
                color: semanticColor.uiColor
            ))
            index += 1
        }

        while index < localizedLines.count {
            rows.append(CoachPresentationWhyRow(
                title: localizedLines[index],
                icon: "info.circle.fill",
                color: semanticColor.uiColor.opacity(0.85)
            ))
            index += 1
        }

        return rows
    }

    private static func shouldMentionDayLoadInWhyRows(_ input: CoachV6CopyBuildInput) -> Bool {
        guard input.dayLoad == .heavy || input.dayLoad == .extreme else { return false }
        switch input.scenario {
        case .morningReadiness, .stableDay, .tomorrowProtection,
             .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled,
             .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            return true
        default:
            return false
        }
    }

    // MARK: - Copy helpers

    private static func localizedText(_ section: CoachV6CopySection) -> String {
        guard let line = section.lines.first else { return "" }
        return localizedText(line)
    }

    private static func localizedText(_ line: CoachV6BilingualText) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? line.russian : line.english
    }

    private static func conciseLine(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func statusLabel(for insight: CoachV6TodayInsight) -> String {
        if insight.safetyAlert != nil {
            return localized(english: "IMPORTANT", russian: "ВАЖНО")
        }

        switch insight.urgencyLevel {
        case .calm:
            return localized(english: "ALL GOOD", russian: "ВСЁ ХОРОШО")

        case .focused:
            return localized(english: "FOCUS NOW", russian: "СЕЙЧАС ВАЖНО")

        case .live:
            return localized(english: "LIVE", russian: "СЕЙЧАС")

        case .protective:
            return localized(english: "SAVE ENERGY", russian: "БЕРЕЖЁМ СИЛЫ")

        case .critical:
            return localized(english: "ATTENTION", russian: "ВНИМАНИЕ")
        }
    }

    private static func coachHeadline(
        scenario: CoachV6ScenarioKey,
        activityType: CoachV6ActivityType,
        stackedDayActiveRisk: Bool = false
    ) -> String {
        if stackedDayActiveRisk {
            return localized(english: "Stacked load", russian: "Нагрузка на пределе")
        }

        switch scenario {
        case .morningReadiness:
            return localized(english: "Morning reset", russian: "С чего начать день")
        case .stableDay:
            return localized(english: "Steady day", russian: "Спокойный день")
        case .duringEndurance:
            switch activityType {
            case .running:
                return localized(english: "On the run", russian: "На пробежке")
            case .cycling:
                return localized(english: "On the ride", russian: "На заезде")
            default:
                return localized(english: "In session", russian: "В тренировке")
            }
        case .walkAfterHeavyLoad:
            return localized(english: "Recovery walk", russian: "Прогулка после нагрузки")
        case .tomorrowProtection:
            return localized(english: "Recovery mode", russian: "Режим восстановления")
        case .protectTomorrowFresh:
            return localized(english: "Save for tomorrow", russian: "Запас на завтра")
        case .recoveryAfterHeavyYesterday:
            return localized(english: "Recovery day", russian: "День восстановления")
        case .lowRecoveryPrep:
            return localized(english: "Check readiness", russian: "Проверьте готовность")
        case .activeEndurance:
            return activeEnduranceHeadline(activityType: activityType)
        case .duringRacket:
            return localized(english: "In the match", russian: "В игре")
        case .duringStrength:
            return localized(english: "Under load", russian: "Под нагрузкой")
        case .duringRecovery:
            return localized(english: "Recovery session", russian: "Сессия восстановления")
        case .postEnduranceImmediate:
            return localized(english: "After the ride", russian: "После заезда")
        case .postRacketImmediate:
            return localized(english: "After the match", russian: "После игры")
        case .postStrengthImmediate:
            return localized(english: "After lifting", russian: "После силовой")
        case .postRecoveryImmediate:
            return localized(english: "Session complete", russian: "Сессия завершена")
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled:
            return localized(english: "Recovering", russian: "Восстанавливаемся")
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            return localized(english: "Day's end", russian: "Завершение дня")
        case .walkLightDay:
            return localized(english: "Easy walk", russian: "Лёгкая прогулка")
        case .walkEveningWindDown:
            return localized(english: "Evening walk", russian: "Вечерняя прогулка")
        case .walkRecoveryAction:
            return localized(english: "Recovery walk", russian: "Прогулка для ног")
        case .activeRacket:
            return localized(english: "Before the match", russian: "Перед игрой")
        case .activeStrength:
            return localized(english: "Before lifting", russian: "Перед силовой")
        case .activeRecovery:
            return localized(english: "Before recovery", russian: "Перед восстановлением")
        case .saunaPreparation:
            return localized(english: "Before sauna", russian: "Перед баней")
        case .saunaActive:
            return localized(english: "In the heat", russian: "В жаре")
        case .saunaRecovery:
            return localized(english: "After sauna", russian: "После бани")
        default:
            return localized(english: "Coach", russian: "Коуч")
        }
    }

    private static func activeEnduranceHeadline(activityType: CoachV6ActivityType) -> String {
        switch activityType {
        case .cycling:
            return localized(english: "Before the ride", russian: "Перед заездом")
        case .running:
            return localized(english: "Before the run", russian: "Перед пробежкой")
        default:
            return localized(english: "Before session", russian: "Перед тренировкой")
        }
    }

    private static func supportIcon(for severity: CoachV6AlertSeverity) -> String {
        switch severity {
        case .none:
            return "info.circle.fill"
        case .elevated:
            return "exclamationmark.circle.fill"
        case .critical:
            return "exclamationmark.triangle.fill"
        }
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}

