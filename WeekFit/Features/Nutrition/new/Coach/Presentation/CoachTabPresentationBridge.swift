import Foundation
import SwiftUI

enum CoachTabPresentationBridge {

    /// Returns UI presentation when `copyPack` exists; otherwise `nil` (registry gap).
    static func build(from engineResult: CoachEngine.Result) -> CoachUIPresentation? {
        guard let pack = engineResult.copyPack else { return nil }

        let insight = engineResult.todayInsight
        let assessment = localizedText(pack.assessment)
        let recommendation = localizedText(pack.recommendation)
        let avoid = localizedText(pack.avoid)
        let nextAction = localizedText(pack.nextAction)
        let supportingSignals = pack.supportingSignals.lines.map(localizedText)
        let warningMessage = pack.warningLayer.map { localizedText($0.message) }
        let teaser = CoachTeaserCopy.resolve(from: engineResult, localizedAssessment: assessment)
        let semanticColor = insight.semanticColor
        let whyRows = supportingWhyRows(
            from: engineResult,
            pack: pack,
            semanticColor: semanticColor
        )

        let ru = WeekFitCurrentLocale().identifier.hasPrefix("ru")

        return CoachUIPresentation(
            scenario: pack.scenario,
            assessment: assessment,
            recommendation: recommendation,
            avoid: avoid,
            nextAction: nextAction,
            supportingSignals: supportingSignals,
            warningMessage: warningMessage,
            warningAlert: pack.warningLayer?.alert,
            semanticColor: semanticColor,
            alertSeverity: insight.alertSeverity,
            icon: insight.icon,
            urgencyLevel: insight.urgencyLevel,
            statusLabel: statusLabel(for: insight),
            coachTitle: localizedText(teaser.coachHeadline),
            todayTitle: singleLineTitle(
                localizedText(teaser.todayTitle),
                maxLength: ru ? 22 : 26
            ),
            todayMessage: todayMessage(
                scenario: pack.scenario,
                teaser: teaser,
                recommendation: recommendation
            ),
            whyRows: whyRows
        )
    }

    // MARK: - Why rows

    private static func supportingWhyRows(
        from engineResult: CoachEngine.Result,
        pack: CoachCopyPack,
        semanticColor: CoachSemanticColor
    ) -> [CoachPresentationWhyRow] {
        let input = CoachCopyBuildInput.from(result: engineResult)
        let localizedLines = pack.supportingSignals.lines.map(localizedText)
        var rows: [CoachPresentationWhyRow] = []
        var index = 0

        if input.modifiers.hydrationBehind, input.safetyAlert != .hydrationCritical, index < localizedLines.count,
           !CoachConversationNutritionPolicy.shouldSuppress(context: engineResult.context) {
            rows.append(CoachPresentationWhyRow(
                title: localizedLines[index],
                icon: "drop.fill",
                color: CoachPalette.hydration
            ))
            index += 1
        }

        if input.modifiers.fuelBehind, input.safetyAlert != .fuelCritical, index < localizedLines.count,
           !CoachConversationNutritionPolicy.shouldSuppress(context: engineResult.context) {
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

    private static func shouldMentionDayLoadInWhyRows(_ input: CoachCopyBuildInput) -> Bool {
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

    // MARK: - Formatting

    private static func todayMessage(
        scenario: CoachScenarioKey,
        teaser: CoachTeaserCopy.Content,
        recommendation: String
    ) -> String {
        let localized = localizedText(teaser.todayMessage)
        if localized.isEmpty {
            return conciseLine(recommendation, maxLength: 72)
        }
        return conciseLine(localized, maxLength: 72)
    }

    /// Today card title must stay on one line — hard cap before UI truncation.
    private static func singleLineTitle(_ text: String, maxLength: Int) -> String {
        conciseLine(text.trimmingCharacters(in: .whitespacesAndNewlines), maxLength: maxLength)
    }

    private static func localizedText(_ section: CoachCopySection) -> String {
        guard let line = section.lines.first else { return "" }
        return localizedText(line)
    }

    private static func localizedText(_ line: CoachBilingualText) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? line.russian : line.english
    }

    private static func conciseLine(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func statusLabel(for insight: CoachTodayInsight) -> String {
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

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}
