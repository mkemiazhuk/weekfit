import Foundation
import SwiftUI

enum CoachTabPresentationBridge {

    /// Returns UI presentation when `copyPack` exists; otherwise `nil` (registry gap).
    static func build(
        from engineResult: CoachEngine.Result,
        showsLimitedConfidenceBadge: Bool = false
    ) -> CoachUIPresentation? {
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
        let coachTitle = localizedText(teaser.coachHeadline)
        let compactHero = CoachUIPresentationDedup.compact(
            CoachUIPresentationDedup.HeroCopy(
                coachTitle: coachTitle,
                assessment: assessment,
                recommendation: recommendation,
                avoid: avoid,
                nextAction: nextAction
            )
        )
        let whyRows = dedupedWhyRows(
            supportingWhyRows(
                from: engineResult,
                pack: pack,
                semanticColor: semanticColor
            ),
            hero: compactHero,
            safetyCritical: pack.warningLayer != nil
        )

        let ru = WeekFitCurrentLocale().identifier.hasPrefix("ru")

        return CoachUIPresentation(
            scenario: pack.scenario,
            assessment: compactHero.assessment,
            recommendation: compactHero.recommendation,
            avoid: compactHero.avoid,
            nextAction: compactHero.nextAction,
            supportingSignals: supportingSignals,
            warningMessage: warningMessage,
            warningAlert: pack.warningLayer?.alert,
            semanticColor: semanticColor,
            alertSeverity: insight.alertSeverity,
            icon: insight.icon,
            urgencyLevel: insight.urgencyLevel,
            statusLabel: statusLabel(
                for: insight,
                context: engineResult.context,
                dayReadiness: engineResult.context.dayReadiness,
                limitedRecovery: showsLimitedConfidenceBadge
            ),
            coachTitle: compactHero.coachTitle,
            todayTitle: singleLineTitle(
                localizedText(teaser.todayTitle),
                maxLength: todayTitleMaxLength(for: pack.scenario, russian: ru)
            ),
            todayMessage: todayMessage(
                scenario: pack.scenario,
                teaser: teaser,
                recommendation: compactHero.recommendation
            ),
            whyRows: whyRows,
            showsLimitedConfidenceBadge: showsLimitedConfidenceBadge
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
        let progress = RelativeProgressPolicy.evaluate(input: input)
        var rows: [CoachPresentationWhyRow] = []
        var index = 0

        if progress.shouldSurfaceHydrationWhyRow, input.safetyAlert != .hydrationCritical, index < localizedLines.count,
           !CoachConversationNutritionPolicy.shouldSuppress(context: engineResult.context) {
            rows.append(CoachPresentationWhyRow(
                title: localizedLines[index],
                icon: "drop.fill",
                color: CoachPalette.hydration
            ))
            index += 1
        }

        if progress.shouldSurfaceFuelWhyRow, input.safetyAlert != .fuelCritical, index < localizedLines.count,
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

    private static func dedupedWhyRows(
        _ rows: [CoachPresentationWhyRow],
        hero: CoachUIPresentationDedup.HeroCopy,
        safetyCritical: Bool
    ) -> [CoachPresentationWhyRow] {
        let heroTexts = [
            hero.coachTitle,
            hero.assessment,
            hero.recommendation,
            hero.avoid,
            hero.nextAction
        ].filter { !$0.isEmpty }

        return rows.filter { row in
            let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return false }

            if heroTexts.contains(where: { CoachUIPresentationDedup.isNearDuplicate($0, title) }) {
                return false
            }

            if !safetyCritical, nutritionTopicDuplicated(row: row, heroTexts: heroTexts) {
                return false
            }

            return true
        }
    }

    private static func nutritionTopicDuplicated(
        row: CoachPresentationWhyRow,
        heroTexts: [String]
    ) -> Bool {
        let heroBlob = heroTexts.joined(separator: " ")
        guard !heroBlob.isEmpty else { return false }

        switch row.icon {
        case "drop.fill":
            return CoachCopyQualityAudit.mentionsHydration(heroBlob)
        case "fork.knife":
            return CoachCopyQualityAudit.mentionsFuel(heroBlob) || mentionsPlannedMealTiming(heroBlob)
        default:
            if mentionsFirstMealAhead(row.title) {
                return mentionsPlannedMealTiming(heroBlob)
            }
            if CoachCopyQualityAudit.mentionsFuel(row.title) {
                return CoachCopyQualityAudit.mentionsFuel(heroBlob)
            }
            if CoachCopyQualityAudit.mentionsHydration(row.title) {
                return CoachCopyQualityAudit.mentionsHydration(heroBlob)
            }
            return false
        }
    }

    private static func mentionsPlannedMealTiming(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("first meal") || lower.contains("usual time") || lower.contains("meal at your") {
            return true
        }
        return text.contains("первый приём пищи")
            || text.contains("привычное время")
            || text.contains("приём пищи ещё впереди")
    }

    private static func mentionsFirstMealAhead(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("first meal is still ahead")
            || text.contains("Первый приём пищи ещё впереди")
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
    private static func todayTitleMaxLength(for scenario: CoachScenarioKey, russian: Bool) -> Int {
        if russian, scenario == .protectTomorrowFresh {
            return 22
        }
        return 26
    }

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

    private static func statusLabel(
        for insight: CoachTodayInsight,
        context: CoachContext,
        dayReadiness: CoachDayReadiness,
        limitedRecovery: Bool
    ) -> String {
        if limitedRecovery {
            return WeekFitLocalizedString("today.coach.chip.limitedRecovery")
        }

        let stableDayProfile = CoachStableDayProfile.resolve(
            scenario: insight.scenario,
            modifiers: insight.modifiers,
            dayReadiness: dayReadiness
        )
        let labels = CoachConversationEnergyBadge.resolve(
            energy: insight.conversationEnergy,
            scenario: insight.scenario,
            safetyAlert: insight.safetyAlert,
            stackedDayActiveRisk: insight.modifiers.stackedDayActiveRisk,
            stableDayProfile: stableDayProfile,
            presentationContext: CoachConversationEnergyBadge.PresentationContext(
                sessionPhase: context.sessionPhase,
                focusSource: context.focusSource,
                activityState: context.activityState,
                completedSeriousActivities: context.completedSeriousActivities,
                dayLoad: context.dayLoadBand
            )
        )
        return localized(english: labels.english, russian: labels.russian)
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}
