import SwiftUI

enum InsightsStoryType: String {
    case changeStory
    case riskStory
    case opportunityStory
    case anomalyStory
    case plateauReversalStory
    case maintenanceStory
}

struct InsightsStoryCandidate {
    let id: String
    let storyType: InsightsStoryType
    let impactScore: Double
    let confidence: Double
    let trend: InsightsHeroInsight
    let driver: InsightSupportCard
    let action: InsightsFocusNext

    var evidence: InsightsEvidence {
        InsightsEvidence(
            label: InsightsLocalization.Section.whyThisStory,
            confidenceLabel: Self.confidenceLabel(for: confidence),
            confidenceValue: confidence,
            sourceSummary: InsightsLocalization.format(
                "insights.story.sourceSummaryFormat",
                InsightsLocalization.storyTypeLabel(storyType),
                Int(impactScore.rounded())
            ),
            recencyText: trend.timeframe,
            bullets: [
                driver.text,
                action.action
            ]
        )
    }

    var displayStory: InsightsStory {
        InsightsStory(
            id: id,
            impactScore: impactScore,
            trend: trend,
            driver: driver,
            action: action,
            evidence: evidence
        )
    }

    private static func confidenceLabel(for confidence: Double) -> String {
        switch confidence {
        case 0.78...:
            return InsightsLocalization.Confidence.high
        case 0.55..<0.78:
            return InsightsLocalization.Confidence.medium
        default:
            return InsightsLocalization.Confidence.low
        }
    }
}

enum InsightsStoryEngine {
    static func topStories(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> [InsightsStoryCandidate] {
        let ranked = storyCandidates(records: records, recoverySleepRecords: recoverySleepRecords)
            .filter(isEligibleStory)
            .filter(validateStory)
            .filter { $0.impactScore >= 45 || $0.storyType == .maintenanceStory }
            .sorted { lhs, rhs in
                if lhs.impactScore != rhs.impactScore {
                    return lhs.impactScore > rhs.impactScore
                }
                return lhs.confidence > rhs.confidence
            }

        guard !ranked.isEmpty else {
            return [fallbackStory(records: records, recoverySleepRecords: recoverySleepRecords, dataQuality: dataQuality)]
        }

        return domainDiverseStories(from: ranked, limit: 2)
    }

    static func fallbackStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> InsightsStoryCandidate {
        if hasEnoughStableContext(dataQuality) {
            let hero = noMajorChangeHero(records: records, recoverySleepRecords: recoverySleepRecords)
            let driver = InsightSupportCard(
                role: .strongestPattern,
                domain: .consistency,
                title: InsightsLocalization.text("insights.fallback.stable.driver.title"),
                text: InsightsLocalization.text("insights.fallback.stable.driver.text"),
                icon: "checkmark.seal.fill",
                accent: hero.accent,
                metrics: [
                    InsightTrendMetric(
                        label: InsightsLocalization.text("insights.signal.read"),
                        value: InsightsLocalization.text("insights.signal.value.noInsight"),
                        direction: .stable,
                        detail: InsightsLocalization.text("insights.signal.detail.notEnoughSeparation"),
                        benchmark: InsightsLocalization.text("insights.signal.detail.keepWatching")
                    )
                ]
            )
            let action = InsightsFocusNext(
                label: InsightsLocalization.Section.action,
                title: InsightsLocalization.text("insights.fallback.stable.action.title"),
                text: InsightsLocalization.text("insights.story.outcome.surfaceNextChange"),
                action: InsightsLocalization.text("insights.fallback.stable.action.action"),
                icon: hero.icon,
                accent: hero.accent,
                domain: .consistency,
                actionTitle: InsightsLocalization.text("insights.action.openCoach"),
                actionDestination: .tab(.coach)
            )

            return InsightsStoryCandidate(
                id: "stable.no_major_change",
                storyType: .maintenanceStory,
                impactScore: 35,
                confidence: confidence(from: dataQuality),
                trend: hero,
                driver: driver,
                action: action
            )
        }

        let hero = missingDataHero(records: records, recoverySleepRecords: recoverySleepRecords)
        let driver = InsightSupportCard(
            role: .strongestPattern,
            domain: .missingData,
            title: InsightsLocalization.text("insights.fallback.baseline.driver.title"),
            text: InsightsLocalization.text("insights.fallback.baseline.driver.text"),
            icon: "sparkles",
            accent: hero.accent,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.read"),
                    value: InsightsLocalization.text("insights.signal.value.building"),
                    direction: .stable,
                    detail: InsightsLocalization.text("insights.signal.detail.notEnoughData"),
                    benchmark: InsightsLocalization.text("insights.signal.detail.complete7Days")
                )
            ]
        )
        let action = InsightsFocusNext(
            label: InsightsLocalization.Section.action,
            title: InsightsLocalization.text("insights.fallback.baseline.action.title"),
            text: InsightsLocalization.text("insights.story.outcome.unlockRankedInsight"),
            action: InsightsLocalization.text("insights.fallback.baseline.action.action"),
            icon: "sparkles",
            accent: hero.accent,
            domain: .missingData,
            actionTitle: InsightsLocalization.text("insights.action.logToday"),
            actionDestination: .tab(.today)
        )

        return InsightsStoryCandidate(
            id: "baseline.insufficient_overlap",
            storyType: .maintenanceStory,
            impactScore: 20,
            confidence: confidence(from: dataQuality),
            trend: hero,
            driver: driver,
            action: action
        )
    }
}

private extension InsightsStoryEngine {
    static func storyCandidates(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> [InsightsStoryCandidate] {
        [
            recoveryDeclineStory(records: records, recoverySleepRecords: recoverySleepRecords),
            recoveryReboundStory(records: records, recoverySleepRecords: recoverySleepRecords),
            recoveryPlateauStory(records: records, recoverySleepRecords: recoverySleepRecords),
            sleepPressureStory(records: records, recoverySleepRecords: recoverySleepRecords),
            sleepBelowTargetStory(records: records, recoverySleepRecords: recoverySleepRecords),
            weekendRecoveryStory(records: records, recoverySleepRecords: recoverySleepRecords),
            trainingLoadStory(records: records, recoverySleepRecords: recoverySleepRecords),
            activeCaloriesDeclineStory(records: records, recoverySleepRecords: recoverySleepRecords),
            proteinSupportStory(records: records, recoverySleepRecords: recoverySleepRecords),
            hydrationHardDayStory(records: records)
        ]
        .compactMap { $0 }
    }

    static func isEligibleStory(_ story: InsightsStoryCandidate) -> Bool {
        switch story.storyType {
        case .changeStory, .riskStory, .opportunityStory, .plateauReversalStory:
            return story.impactScore >= 45
        case .anomalyStory:
            return story.trend.domain != story.driver.domain && story.impactScore >= 45
        case .maintenanceStory:
            return story.id == "stable.no_major_change" || story.id == "baseline.insufficient_overlap"
        }
    }

    static func domainDiverseStories(
        from ranked: [InsightsStoryCandidate],
        limit: Int
    ) -> [InsightsStoryCandidate] {
        var selected: [InsightsStoryCandidate] = []
        var usedDomains: Set<InsightsDomain> = []

        for story in ranked {
            guard !usedDomains.contains(story.trend.domain) else { continue }
            selected.append(story)
            usedDomains.insert(story.trend.domain)

            if selected.count == limit {
                break
            }
        }

        return selected.isEmpty ? Array(ranked.prefix(1)) : selected
    }

    static func validateStory(_ story: InsightsStoryCandidate) -> Bool {
        if story.trend.domain == .missingData || story.id == "stable.no_major_change" {
            return !containsAny(normalized(story.trend.title), ["stable", "consistent"])
        }

        guard usesAllowedInsightPattern(story) else { return false }
        guard !heroIsGenericStable(story.trend.title) else { return false }
        guard !metricContradictsTitle(story.trend) else { return false }
        guard !repeatsMeaning(story.trend.title, story.driver.title, story.driver.text) else { return false }
        guard !repeatsMeaning(story.driver.title, story.action.title, story.action.action) else { return false }
        guard !actionContradictsTrend(story) else { return false }
        guard !sameDomainWithoutCausalDistinction(story) else { return false }
        guard !expectedOutcomeRepeatsTrend(story) else { return false }
        return readsAsCoherentSentence(story)
    }

    static func usesAllowedInsightPattern(_ story: InsightsStoryCandidate) -> Bool {
        switch story.storyType {
        case .changeStory, .riskStory, .opportunityStory, .anomalyStory, .plateauReversalStory:
            return true
        case .maintenanceStory:
            return story.id == "baseline.insufficient_overlap" || story.id == "stable.no_major_change"
        }
    }

    static func heroIsGenericStable(_ title: String) -> Bool {
        let copy = normalized(title)
        let hasStableClaim = containsAny(copy, [
            "stable",
            "consistent",
            "remains healthy",
            "holding"
        ])
        guard hasStableClaim else { return false }

        return !containsAny(copy, [
            "despite",
            "while",
            "after",
            "although",
            "but"
        ])
    }

    static func metricContradictsTitle(_ hero: InsightsHeroInsight) -> Bool {
        let title = normalized(hero.title)
        let metricText = normalized([hero.badgeValue, hero.badgeLabel, hero.targetLabel ?? ""].joined(separator: " "))

        if title.contains("sleep") && title.contains("below target") {
            return !metricText.contains("h") || metricText.contains("score")
        }

        if title.contains("duration") {
            return !metricText.contains("h") || metricText.contains("score")
        }

        if title.contains("score") {
            return metricText.contains("h")
        }

        return false
    }

    static func repeatsMeaning(_ firstTitle: String, _ secondTitle: String, _ secondBody: String) -> Bool {
        let firstTokens = salientTokens(firstTitle)
        let secondTokens = salientTokens([secondTitle, secondBody].joined(separator: " "))
        guard !firstTokens.isEmpty, !secondTokens.isEmpty else { return false }

        let overlap = firstTokens.intersection(secondTokens)
        if overlap.count >= min(3, firstTokens.count) {
            return !containsCausalConnector([firstTitle, secondTitle, secondBody].joined(separator: " "))
        }

        return normalized(firstTitle) == normalized(secondTitle) || normalized(firstTitle) == normalized(secondBody)
    }

    static func actionContradictsTrend(_ story: InsightsStoryCandidate) -> Bool {
        let trend = normalized([story.trend.title, story.trend.subtitle, story.trend.takeaway].joined(separator: " "))
        let action = normalized([story.action.title, story.action.action].joined(separator: " "))

        if containsAny(trend, ["stable", "holding"]) && action.contains("stabilize") {
            return true
        }

        if trend.contains("supporting the trend") && containsAny(action, ["do not add load", "hold current"]) {
            return true
        }

        if trend.contains("absorbing high load") && action.contains("do not add load yet") {
            return true
        }

        return false
    }

    static func sameDomainWithoutCausalDistinction(_ story: InsightsStoryCandidate) -> Bool {
        guard story.trend.domain == story.driver.domain,
              story.driver.domain == story.action.domain else {
            return false
        }

        if story.storyType == .plateauReversalStory || story.id == "stable.no_major_change" {
            return false
        }

        return !containsCausalConnector([
            story.trend.title,
            story.trend.subtitle,
            story.driver.text,
            story.action.title,
            story.action.action
        ].joined(separator: " "))
    }

    static func expectedOutcomeRepeatsTrend(_ story: InsightsStoryCandidate) -> Bool {
        let expected = normalized(story.action.text)
        guard !expected.isEmpty else { return false }

        let trendTokens = salientTokens([story.trend.title, story.trend.subtitle].joined(separator: " "))
        let expectedTokens = salientTokens(expected)
        return !expectedTokens.isEmpty && expectedTokens.isSubset(of: trendTokens)
    }

    static func readsAsCoherentSentence(_ story: InsightsStoryCandidate) -> Bool {
        let sentence = "\(story.trend.title), because \(story.driver.text), so \(story.action.action)"
        let copy = normalized(sentence)
        return copy.contains("because") && copy.contains("so") && !containsAny(copy, [
            "because ,",
            "so .",
            "stable, because stable"
        ])
    }

    static func containsCausalConnector(_ text: String) -> Bool {
        containsAny(normalized(text), [
            "despite",
            "while",
            "after",
            "although",
            "but",
            "because",
            "then",
            "before",
            "outpacing",
            "absorbing",
            "reduces",
            "separating"
        ])
    }

    static func salientTokens(_ text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "the", "is", "are", "and", "or", "to", "a", "an", "of", "for", "in",
            "on", "this", "that", "your", "with", "by", "but", "has", "have",
            "at", "yet", "next", "current", "before", "after", "while"
        ]

        return Set(normalized(text)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) })
    }

    static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    static func normalized(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "7 hours", with: "7h")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".+-/")).inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func recoveryDeclineStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        guard recoveryRecords.count >= 14 else { return nil }

        let recent = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baseline = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let delta = recent - baseline
        guard baseline > 0, delta <= -4 else { return nil }

        let latest = recoveryRecords.last?.recoveryScore ?? Int(recent.rounded())
        let driver = strongestRecoveryDriver(records: records, recoverySleepRecords: recoverySleepRecords, recoveryAccent: WeekFitTheme.meal)
        let confidenceValue = storyConfidence(primaryDays: recoveryRecords.count, pairedDays: recoverySleepRecords.filter { $0.recoveryScore > 0 && $0.sleepMinutes > 0 }.count)

        return InsightsStoryCandidate(
            id: "recovery.decline",
            storyType: .changeStory,
            impactScore: min(96, 58 + abs(delta) * 4 + (recent < 68 ? 12 : 0)),
            confidence: confidenceValue,
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: latest >= 72
                    ? InsightsLocalization.text("insights.story.recovery.decline.titleHealthy")
                    : InsightsLocalization.text("insights.story.recovery.decline.titleLosing"),
                subtitle: InsightsLocalization.format(
                    "insights.story.recovery.decline.subtitleFormat",
                    Int(abs(delta).rounded())
                ),
                takeaway: InsightsLocalization.text("insights.story.recovery.decline.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: InsightsLocalization.text("insights.story.target.recovery72"),
                badgeValue: "\(latest)",
                badgeLabel: InsightsLocalization.text("insights.story.badge.recovery"),
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: driver.domain == .sleep
                    ? InsightsLocalization.text("insights.story.recovery.decline.action.sleepTitle")
                    : InsightsLocalization.text("insights.story.recovery.decline.action.driverTitle"),
                action: driver.domain == .sleep
                    ? InsightsLocalization.text("insights.story.recovery.decline.action.sleepAction")
                    : InsightsLocalization.text("insights.story.recovery.decline.action.easyWorkouts")
            )
        )
    }

    static func recoveryReboundStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        guard recoveryRecords.count >= 14 else { return nil }

        let recent = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baseline = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let delta = recent - baseline
        guard baseline > 0, delta >= 5 else { return nil }

        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let volume = trainingVolumeSummary(records)
        let loadChange = workloadBaselineChange(volume)
        let driver: InsightSupportCard

        if recentSleep >= 7 {
            driver = InsightSupportCard(
                role: .resilience,
                domain: .sleep,
                title: InsightsLocalization.text("insights.story.driver.sleepConsistency.title"),
                text: InsightsLocalization.text("insights.story.driver.sleepConsistency.text"),
                icon: "moon.fill",
                accent: WeekFitTheme.meal,
                metrics: [
                    InsightTrendMetric(
                        label: InsightsLocalization.text("insights.signal.sleep"),
                        value: "\(formatOneDecimal(recentSleep))h",
                        direction: .stable,
                        detail: InsightsLocalization.text("insights.signal.average"),
                        benchmark: InsightsLocalization.text("insights.signal.target7h")
                    )
                ]
            )
        } else if volume.hasMeaningfulLoad, loadChange <= 10 {
            driver = InsightSupportCard(
                role: .workload,
                domain: .activity,
                title: InsightsLocalization.text("insights.story.driver.controlledLoad.title"),
                text: InsightsLocalization.text("insights.story.driver.controlledLoad.text"),
                icon: "figure.run",
                accent: WeekFitTheme.meal,
                metrics: [
                    workloadSignificanceMetric(volume)
                ]
            )
        } else {
            return nil
        }

        return InsightsStoryCandidate(
            id: "recovery.rebound",
            storyType: .opportunityStory,
            impactScore: min(88, 52 + delta * 4),
            confidence: storyConfidence(primaryDays: recoveryRecords.count, pairedDays: max(sleepRecords.count, records.filter(\.hasActivitySignal).count)),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: InsightsLocalization.text("insights.story.recovery.rebound.title"),
                subtitle: InsightsLocalization.format(
                    "insights.story.recovery.rebound.subtitleFormat",
                    Int(delta.rounded())
                ),
                takeaway: InsightsLocalization.text("insights.story.recovery.rebound.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: InsightsLocalization.text("insights.story.target.recovery72"),
                badgeValue: "\(Int(recent.rounded()))",
                badgeLabel: InsightsLocalization.text("insights.story.badge.recovery"),
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: driver.domain == .sleep
                    ? InsightsLocalization.text("insights.story.recovery.rebound.action.sleepTitle")
                    : InsightsLocalization.text("insights.story.recovery.rebound.action.loadTitle"),
                action: driver.domain == .sleep
                    ? InsightsLocalization.text("insights.story.recovery.rebound.action.sleepAction")
                    : InsightsLocalization.text("insights.story.recovery.rebound.action.loadAction")
            )
        )
    }

    static func recoveryPlateauStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        guard recoveryRecords.count >= 21 else { return nil }

        let firstWindow = average(Array(recoveryRecords.prefix(10)).map { Double($0.recoveryScore) })
        let middleWindow = average(Array(recoveryRecords.dropFirst(10).prefix(10)).map { Double($0.recoveryScore) })
        let recent = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        guard middleWindow - firstWindow >= 4, abs(recent - middleWindow) <= 2 else { return nil }

        let driver = InsightSupportCard(
            role: .resilience,
            domain: .recovery,
            title: InsightsLocalization.text("insights.story.driver.recoveryPlateau.title"),
            text: InsightsLocalization.text("insights.story.driver.recoveryPlateau.text"),
            icon: "equal.circle.fill",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.recentTrend"),
                    value: InsightsLocalization.text("insights.signal.value.flat"),
                    direction: .stable,
                    detail: InsightsLocalization.text("insights.signal.detail.afterImprovement"),
                    benchmark: InsightsLocalization.text("insights.signal.benchmark.plateau")
                )
            ]
        )

        return InsightsStoryCandidate(
            id: "recovery.plateau",
            storyType: .plateauReversalStory,
            impactScore: 64,
            confidence: storyConfidence(primaryDays: recoveryRecords.count, pairedDays: recoveryRecords.count),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: InsightsLocalization.text("insights.story.recovery.plateau.title"),
                subtitle: InsightsLocalization.text("insights.story.recovery.plateau.subtitle"),
                takeaway: InsightsLocalization.text("insights.story.recovery.plateau.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "equal.circle.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: InsightsLocalization.text("insights.story.target.recovery72"),
                badgeValue: "\(Int(recent.rounded()))",
                badgeLabel: InsightsLocalization.text("insights.story.badge.recovery"),
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: InsightsLocalization.text("insights.story.recovery.plateau.action.title"),
                action: InsightsLocalization.text("insights.story.recovery.plateau.action.action")
            )
        )
    }

    static func sleepPressureStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        guard sleepRecords.count >= 7, recoveryRecords.count >= 7 else { return nil }

        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let baselineSleep = average(Array(sleepRecords.dropLast(7)).map(\.sleepHours))
        let sleepDeclining = baselineSleep > 0 && recentSleep <= baselineSleep - 0.25
        guard recentSleep < 6.9 || sleepDeclining else { return nil }

        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDelta = recentRecovery - baselineRecovery
        let recoveryStable = baselineRecovery > 0 && abs(recoveryDelta) <= 3
        let recoveryDeclining = baselineRecovery > 0 && recoveryDelta <= -3
        guard recoveryStable || recoveryDeclining else { return nil }

        let sleepGap = max(0, 7.0 - recentSleep)
        let recoveryGap = recentRecovery - 72
        let trendTitle = recoveryDeclining
            ? InsightsLocalization.text("insights.story.sleepPressure.trendLosingSupport")
            : InsightsLocalization.text("insights.story.sleepPressure.trendHoldingDespite")
        let driverText = recoveryDeclining
            ? InsightsLocalization.format(
                "insights.story.driver.sleepDuration.gapDecliningFormat",
                sleepGap,
                Int(abs(recoveryDelta).rounded())
            )
            : InsightsLocalization.format(
                "insights.story.driver.sleepDuration.gapStableFormat",
                sleepGap,
                recoveryGap >= 0
                    ? InsightsLocalization.text("insights.story.driver.sleepDuration.above")
                    : InsightsLocalization.text("insights.story.driver.sleepDuration.near")
            )

        let driver = InsightSupportCard(
            role: .limitingFactor,
            domain: .sleep,
            title: InsightsLocalization.text("insights.story.driver.sleepDuration.title"),
            text: driverText,
            icon: "moon.fill",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.sleep"),
                    value: "\(formatOneDecimal(recentSleep))h",
                    direction: sleepDeclining ? .decreasing : .stable,
                    detail: InsightsLocalization.text("insights.signal.average"),
                    benchmark: InsightsLocalization.text("insights.signal.target7h")
                )
            ]
        )

        return InsightsStoryCandidate(
            id: recoveryDeclining ? "recovery.sleep_risk" : "recovery.short_sleep_mismatch",
            storyType: recoveryDeclining ? .riskStory : .anomalyStory,
            impactScore: min(82, 46 + max(0, 7.0 - recentSleep) * 10 + (sleepDeclining ? 8 : 0) + (recoveryDeclining ? 14 : 0) + (recoveryStable ? 12 : 0)),
            confidence: storyConfidence(primaryDays: sleepRecords.count, pairedDays: recoverySleepRecords.filter { $0.sleepMinutes > 0 && $0.recoveryScore > 0 }.count),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: trendTitle,
                subtitle: recoveryDeclining
                    ? InsightsLocalization.format(
                        "insights.story.sleepPressure.subtitleDecliningFormat",
                        Int(abs(recoveryDelta).rounded())
                    )
                    : InsightsLocalization.format(
                        "insights.story.sleepPressure.subtitleStableFormat",
                        recentSleep
                    ),
                takeaway: InsightsLocalization.text("insights.story.sleepPressure.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: InsightsLocalization.text("insights.story.target.recovery72"),
                badgeValue: "\(recoveryRecords.last?.recoveryScore ?? Int(recentRecovery.rounded()))",
                badgeLabel: InsightsLocalization.text("insights.story.badge.recovery"),
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: InsightsLocalization.text("insights.story.sleepPressure.action.title"),
                text: recoveryDeclining
                    ? InsightsLocalization.text("insights.story.outcome.restoreRecoveryMargin")
                    : InsightsLocalization.text("insights.story.outcome.preserveRecoveryMargin"),
                action: InsightsLocalization.text("insights.story.sleepPressure.action.action")
            )
        )
    }

    static func sleepBelowTargetStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        guard sleepRecords.count >= 14 else { return nil }

        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let baselineSleep = average(Array(sleepRecords.dropLast(7)).map(\.sleepHours))
        let sleepDeclining = baselineSleep > 0 && recentSleep <= baselineSleep - 0.35
        guard recentSleep < 6.5 || sleepDeclining else { return nil }
        let sleepGap = max(0, 7.0 - recentSleep)

        let driver = InsightSupportCard(
            role: .limitingFactor,
            domain: .sleep,
            title: InsightsLocalization.text("insights.story.driver.sleepDuration.title"),
            text: InsightsLocalization.format(
                "insights.story.driver.sleepDuration.belowTargetFormat",
                sleepGap
            ),
            icon: "moon.fill",
            accent: WeekFitTheme.purple,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.sleep"),
                    value: "\(formatOneDecimal(recentSleep))h",
                    direction: sleepDeclining ? .decreasing : .stable,
                    detail: InsightsLocalization.text("insights.signal.average"),
                    benchmark: InsightsLocalization.text("insights.signal.target7h")
                )
            ]
        )

        return InsightsStoryCandidate(
            id: "sleep.below_target",
            storyType: .riskStory,
            impactScore: min(76, 48 + max(0, 7.0 - recentSleep) * 11 + (sleepDeclining ? 10 : 0)),
            confidence: storyConfidence(primaryDays: sleepRecords.count, pairedDays: sleepRecords.count),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: InsightsLocalization.text("insights.story.sleepBelowTarget.title"),
                subtitle: InsightsLocalization.format(
                    "insights.story.sleepBelowTarget.subtitleFormat",
                    recentSleep
                ),
                takeaway: InsightsLocalization.text("insights.story.sleepBelowTarget.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "moon.fill",
                accent: WeekFitTheme.purple,
                graphValues: sleepDurationTrendValues(sleepRecords),
                targetValue: 7.0 / 8.0,
                targetLabel: InsightsLocalization.text("insights.story.target.sleep7h"),
                badgeValue: "\(formatOneDecimal(recentSleep))h",
                badgeLabel: InsightsLocalization.text("insights.story.badge.average"),
                domain: .sleep,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: InsightsLocalization.text("insights.story.sleepPressure.action.title"),
                text: InsightsLocalization.text("insights.story.outcome.closeSleepGap"),
                action: InsightsLocalization.text("insights.story.sleepPressure.action.action"),
                icon: "moon.zzz.fill",
                accent: WeekFitTheme.purple,
                domain: .sleep,
                destination: .detail(.recovery)
            )
        )
    }

    static func weekendRecoveryStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let paired = recoverySleepRecords.filter { $0.sleepMinutes > 0 && $0.recoveryScore > 0 }
        let weekend = paired.filter { Calendar.current.isDateInWeekend($0.date) }
        let weekday = paired.filter { !Calendar.current.isDateInWeekend($0.date) }
        guard weekend.count >= 4, weekday.count >= 8 else { return nil }

        let weekendSleep = average(weekend.map(\.sleepHours))
        let weekdaySleep = average(weekday.map(\.sleepHours))
        let weekendRecovery = average(weekend.map { Double($0.recoveryScore) })
        let weekdayRecovery = average(weekday.map { Double($0.recoveryScore) })
        let recoveryGap = weekdayRecovery - weekendRecovery
        guard weekendSleep <= weekdaySleep - 0.35, recoveryGap >= 4 else { return nil }

        let driver = InsightSupportCard(
            role: .limitingFactor,
            domain: .sleep,
            title: InsightsLocalization.text("insights.story.driver.weekendSleep.title"),
            text: InsightsLocalization.text("insights.story.driver.weekendSleep.text"),
            icon: "calendar",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.weekendGap"),
                    value: "-\(Int(recoveryGap.rounded()))",
                    direction: .decreasing,
                    detail: InsightsLocalization.text("insights.signal.recoveryPoints"),
                    benchmark: InsightsLocalization.text("insights.signal.vsWeekdays")
                )
            ]
        )

        return InsightsStoryCandidate(
            id: "recovery.weekend_sleep_mismatch",
            storyType: .anomalyStory,
            impactScore: min(86, 54 + recoveryGap * 3),
            confidence: storyConfidence(primaryDays: paired.count, pairedDays: weekend.count),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: InsightsLocalization.text("insights.story.weekendRecovery.title"),
                subtitle: InsightsLocalization.format(
                    "insights.story.weekendRecovery.subtitleFormat",
                    Int(recoveryGap.rounded())
                ),
                takeaway: InsightsLocalization.text("insights.story.weekendRecovery.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(paired.suffix(30)))),
                targetValue: 0.72,
                targetLabel: InsightsLocalization.text("insights.story.target.recovery72"),
                badgeValue: "\(Int(average(Array(paired.suffix(7)).map { Double($0.recoveryScore) }).rounded()))",
                badgeLabel: InsightsLocalization.text("insights.story.badge.recovery"),
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: InsightsLocalization.text("insights.story.weekendRecovery.action.title"),
                action: InsightsLocalization.text("insights.story.weekendRecovery.action.action")
            )
        )
    }

    static func trainingLoadStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let volume = trainingVolumeSummary(records)
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDelta = recentRecovery - baselineRecovery
        guard volume.hasMeaningfulLoad, recoveryRecords.count >= 7 else { return nil }

        let loadPressure = workloadBaselineChange(volume)
        let highLoad = workloadCategory(volume) == "High Load" || loadPressure >= 100
        let stableMismatch = highLoad && baselineRecovery > 0 && abs(recoveryDelta) <= 3 && recentRecovery >= 72
        let risk = loadPressure >= 15 && (recentRecovery < 70 || recoveryDelta <= -3)
        guard stableMismatch || risk else { return nil }

        let driver = InsightSupportCard(
            role: .workload,
            domain: .activity,
            title: InsightsLocalization.text("insights.story.driver.trainingLoad.title"),
            text: stableMismatch
                ? InsightsLocalization.text("insights.story.driver.trainingLoad.highStable")
                : InsightsLocalization.text("insights.story.driver.trainingLoad.outpacingShort"),
            icon: "figure.run",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.load"),
                    value: InsightsLocalization.localizedWorkloadCategory(workloadCategory(volume)),
                    direction: .increasing,
                    detail: volume.badgeValue,
                    benchmark: InsightsLocalization.text("insights.signal.aboveRecentBase")
                )
            ]
        )

        return InsightsStoryCandidate(
            id: stableMismatch ? "recovery.stable_despite_load" : "recovery.load_risk",
            storyType: stableMismatch ? .anomalyStory : .riskStory,
            impactScore: min(94, 58 + loadPressure * 0.5 + max(0, -recoveryDelta) * 3),
            confidence: storyConfidence(primaryDays: records.filter(\.hasActivitySignal).count, pairedDays: recoveryRecords.count),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: stableMismatch
                    ? InsightsLocalization.text("insights.story.trainingLoad.trendAbsorbing")
                    : InsightsLocalization.text("insights.story.trainingLoad.trendNotKeepingUp"),
                subtitle: stableMismatch
                    ? InsightsLocalization.text("insights.story.trainingLoad.subtitleStable")
                    : InsightsLocalization.text("insights.story.trainingLoad.subtitleRisk"),
                takeaway: stableMismatch
                    ? InsightsLocalization.text("insights.story.trainingLoad.takeawayStable")
                    : InsightsLocalization.text("insights.story.trainingLoad.takeawayRisk"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: InsightsLocalization.text("insights.story.target.recovery72"),
                visualization: .correlation(
                    primary: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                    secondary: smoothedTrendValues(recoverySleepRecords.map(\.activityLoadGraphValue)),
                    primaryLabel: InsightsLocalization.text("insights.signal.correlation.recovery"),
                    secondaryLabel: InsightsLocalization.text("insights.signal.correlation.load")
                ),
                badgeValue: "\(Int(recentRecovery.rounded()))",
                badgeLabel: InsightsLocalization.text("insights.story.badge.recovery"),
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: stableMismatch
                    ? InsightsLocalization.text("insights.story.trainingLoad.action.holdBeforeIncrease")
                    : InsightsLocalization.text("insights.story.trainingLoad.action.holdVolume"),
                text: stableMismatch
                    ? InsightsLocalization.text("insights.story.outcome.confirmLoadSustainable")
                    : InsightsLocalization.text("insights.story.outcome.letRecoveryCatchUp"),
                action: stableMismatch
                    ? InsightsLocalization.text("insights.story.trainingLoad.action.holdLoadAction")
                    : InsightsLocalization.text("insights.story.trainingLoad.action.noIncreaseAction")
            )
        )
    }

    static func activeCaloriesDeclineStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let calorieRecords = recoverySleepRecords.filter { $0.metrics.activeCalories > 0 }
        guard calorieRecords.count >= 14 else { return nil }

        let recent = average(Array(calorieRecords.suffix(7)).map(\.metrics.activeCalories))
        let baseline = average(Array(calorieRecords.dropLast(7)).map(\.metrics.activeCalories))
        guard baseline > 0, recent <= baseline * 0.75 else { return nil }

        let drop = baseline - recent
        let accent = WeekFitTheme.orange
        let driver = InsightSupportCard(
            role: .workload,
            domain: .activity,
            title: InsightsLocalization.text("insights.story.driver.activeCalories.title"),
            text: InsightsLocalization.text("insights.story.driver.activeCalories.text"),
            icon: "flame.fill",
            accent: accent,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.activeCalories"),
                    value: "-\(Int(drop.rounded()))",
                    direction: .decreasing,
                    detail: InsightsLocalization.text("insights.signal.perDay"),
                    benchmark: InsightsLocalization.text("insights.signal.vsBaseline")
                )
            ]
        )

        return InsightsStoryCandidate(
            id: "activity.active_calories_declining",
            storyType: .changeStory,
            impactScore: min(78, 46 + (drop / max(baseline, 1)) * 80),
            confidence: storyConfidence(primaryDays: calorieRecords.count, pairedDays: calorieRecords.count),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: InsightsLocalization.text("insights.story.activeCalories.title"),
                subtitle: InsightsLocalization.text("insights.story.activeCalories.subtitle"),
                takeaway: InsightsLocalization.text("insights.story.activeCalories.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "flame.fill",
                accent: accent,
                graphValues: smoothedTrendValues(calorieRecords.map { min(max($0.metrics.activeCalories / max(baseline, 1), 0), 1) }),
                targetValue: 0.85,
                targetLabel: InsightsLocalization.text("insights.story.badge.baseline"),
                badgeValue: "\(Int(recent.rounded()))",
                badgeLabel: InsightsLocalization.text("insights.story.badge.calPerDay"),
                domain: .activity,
                actionDestination: .detail(.activity)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: InsightsLocalization.text("insights.story.activeCalories.action.title"),
                action: InsightsLocalization.text("insights.story.activeCalories.action.action")
            )
        )
    }

    static func proteinSupportStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let nutritionRecords = records.filter { $0.mealCount > 0 || $0.proteinGrams > 0 }
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        guard nutritionRecords.count >= 4, recoveryRecords.count >= 7, proteinGoal > 0 else { return nil }

        let hitDays = nutritionRecords.filter { $0.proteinGrams >= proteinGoal }.count
        let averageProtein = average(nutritionRecords.map(\.proteinGrams))
        guard hitDays < 5 || averageProtein < proteinGoal * 0.75 else { return nil }

        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDelta = recentRecovery - baselineRecovery
        let stableMissingSignal = baselineRecovery > 0 && abs(recoveryDelta) <= 3 && hitDays <= 3
        let decliningSupport = baselineRecovery > 0 && recoveryDelta <= -3
        guard stableMissingSignal || decliningSupport else { return nil }

        let driver = InsightSupportCard(
            role: .limitingFactor,
            domain: .nutrition,
            title: InsightsLocalization.text("insights.story.driver.proteinConsistency.title"),
            text: InsightsLocalization.text("insights.story.driver.proteinConsistency.text"),
            icon: "fork.knife",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.protein"),
                    value: "\(hitDays)/7",
                    direction: .decreasing,
                    detail: InsightsLocalization.text("insights.signal.targetDays"),
                    benchmark: InsightsLocalization.text("insights.signal.target6of7")
                )
            ]
        )

        return InsightsStoryCandidate(
            id: decliningSupport ? "recovery.protein_risk" : "recovery.nutrition_signal_gap",
            storyType: decliningSupport ? .riskStory : .opportunityStory,
            impactScore: min(74, 44 + Double(max(0, 6 - hitDays)) * 4 + max(0, 1 - averageProtein / proteinGoal) * 16 + (decliningSupport ? 10 : 0)),
            confidence: storyConfidence(primaryDays: nutritionRecords.count, pairedDays: nutritionRecords.count),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: decliningSupport
                    ? InsightsLocalization.text("insights.story.protein.trendWeaker")
                    : InsightsLocalization.text("insights.story.protein.trendMissingSignal"),
                subtitle: InsightsLocalization.format(
                    "insights.story.protein.subtitleFormat",
                    hitDays
                ),
                takeaway: InsightsLocalization.text("insights.story.protein.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: InsightsLocalization.text("insights.story.target.recovery72"),
                badgeValue: "\(Int(recentRecovery.rounded()))",
                badgeLabel: InsightsLocalization.text("insights.story.badge.recovery"),
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: InsightsLocalization.text("insights.story.protein.action.title"),
                action: InsightsLocalization.text("insights.story.protein.action.action")
            )
        )
    }

    static func hydrationHardDayStory(records: [InsightsDayRecord]) -> InsightsStoryCandidate? {
        let paired = records.filter { $0.waterLiters > 0 && $0.hasActivitySignal && $0.recoveryScore > 0 }
        guard paired.count >= 4 else { return nil }

        let highLoadDays = paired.filter { $0.activityLoadScore >= 55 }
        guard highLoadDays.count >= 2 else { return nil }

        let lowerHydration = highLoadDays.filter { $0.waterLiters < max($0.waterGoal, 2.4) * 0.7 }
        let betterHydration = highLoadDays.filter { $0.waterLiters >= max($0.waterGoal, 2.4) * 0.7 }
        guard !lowerHydration.isEmpty, !betterHydration.isEmpty else { return nil }

        let lowerRecovery = average(lowerHydration.map { Double($0.recoveryScore) })
        let betterRecovery = average(betterHydration.map { Double($0.recoveryScore) })
        let lift = betterRecovery - lowerRecovery
        guard abs(lift) >= 5 else { return nil }

        let driver = InsightSupportCard(
            role: .relationship,
            domain: .hydration,
            title: InsightsLocalization.text("insights.story.driver.hydrationHardDays.title"),
            text: InsightsLocalization.text("insights.story.driver.hydrationHardDays.text"),
            icon: "drop.fill",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.hardDays"),
                    value: lift > 0 ? "+\(Int(lift.rounded()))" : "\(Int(lift.rounded()))",
                    direction: lift > 0 ? .increasing : .decreasing,
                    detail: InsightsLocalization.text("insights.signal.recoveryPoints"),
                    benchmark: InsightsLocalization.text("insights.signal.hydratedVsLowFluid")
                )
            ]
        )

        return InsightsStoryCandidate(
            id: "recovery.hydration_hard_day_effect",
            storyType: .anomalyStory,
            impactScore: min(76, 46 + abs(lift) * 4),
            confidence: storyConfidence(primaryDays: paired.count, pairedDays: highLoadDays.count),
            trend: InsightsHeroInsight(
                label: InsightsLocalization.Section.trend,
                title: InsightsLocalization.text("insights.story.hydration.title"),
                subtitle: InsightsLocalization.format(
                    "insights.story.hydration.subtitleFormat",
                    Int(abs(lift).rounded())
                ),
                takeaway: InsightsLocalization.text("insights.story.hydration.takeaway"),
                timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(paired.suffix(30)))),
                targetValue: 0.72,
                targetLabel: InsightsLocalization.text("insights.story.target.recovery72"),
                badgeValue: "\(Int(average(Array(paired.suffix(7)).map { Double($0.recoveryScore) }).rounded()))",
                badgeLabel: InsightsLocalization.text("insights.story.badge.recovery"),
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForDriver(
                driver,
                title: InsightsLocalization.text("insights.story.hydration.action.title"),
                action: InsightsLocalization.text("insights.story.hydration.action.action")
            )
        )
    }
}

private extension InsightsStoryEngine {
    static func strongestRecoveryDriver(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        recoveryAccent: Color
    ) -> InsightSupportCard {
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let baselineSleep = average(Array(sleepRecords.dropLast(7)).map(\.sleepHours))

        if recentSleep > 0, recentSleep < 7 || (baselineSleep > 0 && recentSleep <= baselineSleep - 0.25) {
            return InsightSupportCard(
                role: .limitingFactor,
                domain: .sleep,
                title: InsightsLocalization.text("insights.story.driver.sleepDuration.title"),
                text: InsightsLocalization.text("insights.story.driver.sleepDuration.belowRecovery"),
                icon: "moon.fill",
                accent: recoveryAccent,
                metrics: [
                    InsightTrendMetric(
                        label: InsightsLocalization.text("insights.signal.sleep"),
                        value: "\(formatOneDecimal(recentSleep))h",
                        direction: .decreasing,
                        detail: InsightsLocalization.text("insights.signal.average"),
                        benchmark: InsightsLocalization.text("insights.signal.target7h")
                    )
                ]
            )
        }

        let volume = trainingVolumeSummary(records)
        if volume.hasMeaningfulLoad, workloadBaselineChange(volume) >= 15 {
            return InsightSupportCard(
                role: .workload,
                domain: .activity,
                title: InsightsLocalization.text("insights.story.driver.trainingLoad.title"),
                text: InsightsLocalization.text("insights.story.driver.trainingLoad.outpacing"),
                icon: "figure.run",
                accent: recoveryAccent,
                metrics: [
                    workloadSignificanceMetric(volume)
                ]
            )
        }

        return InsightSupportCard(
            role: .resilience,
            domain: .recovery,
            title: InsightsLocalization.text("insights.story.driver.recoveryConsistency.title"),
            text: InsightsLocalization.text("insights.story.driver.recoveryConsistency.text"),
            icon: "heart.fill",
            accent: recoveryAccent,
            metrics: [
                InsightTrendMetric(
                    label: InsightsLocalization.text("insights.signal.recovery"),
                    value: InsightsLocalization.text("insights.signal.value.down"),
                    direction: .decreasing,
                    detail: InsightsLocalization.text("insights.signal.vsBaselineShort"),
                    benchmark: InsightsLocalization.text("insights.signal.recent7Days")
                )
            ]
        )
    }

    static func actionForDriver(
        _ driver: InsightSupportCard,
        title: String,
        text: String? = nil,
        action: String
    ) -> InsightsFocusNext {
        actionForStory(
            title: title,
            text: text ?? expectedOutcome(for: driver.domain),
            action: action,
            icon: driver.icon,
            accent: driver.accent,
            domain: driver.domain,
            destination: destination(for: driver.domain)
        )
    }

    static func actionForStory(
        title: String,
        text: String,
        action: String,
        icon: String,
        accent: Color,
        domain: InsightsDomain,
        destination: InsightsActionDestination?
    ) -> InsightsFocusNext {
        InsightsFocusNext(
            label: InsightsLocalization.Section.action,
            title: title,
            text: text,
            action: action,
            icon: icon,
            accent: accent,
            domain: domain,
            actionTitle: storyActionTitle(for: destination),
            actionDestination: destination
        )
    }

    static func expectedOutcome(for domain: InsightsDomain) -> String {
        switch domain {
        case .sleep:
            return InsightsLocalization.text("insights.story.outcome.restoreRecoveryMargin")
        case .recovery:
            return InsightsLocalization.text("insights.story.outcome.confirmRecoveryResponding")
        case .activity:
            return InsightsLocalization.text("insights.story.outcome.confirmLoadSustainable")
        case .nutrition:
            return InsightsLocalization.text("insights.story.outcome.makeRecoveryEasierToExplain")
        case .hydration:
            return InsightsLocalization.text("insights.story.outcome.makeHardDayRecoveryEasier")
        case .consistency, .missingData:
            return InsightsLocalization.text("insights.story.outcome.surfaceRankedInsight")
        }
    }

    static func destination(for domain: InsightsDomain) -> InsightsActionDestination? {
        switch domain {
        case .activity:
            return .detail(.activity)
        case .nutrition, .hydration:
            return .detail(.nutrition)
        case .sleep, .recovery:
            return .detail(.recovery)
        case .consistency:
            return .tab(.coach)
        case .missingData:
            return .tab(.today)
        }
    }

    static func storyActionTitle(for destination: InsightsActionDestination?) -> String {
        switch destination {
        case .detail(.recovery):
            return InsightsLocalization.text("insights.action.viewRecoveryAnalysis")
        case .detail(.activity):
            return InsightsLocalization.text("insights.action.reviewTrainingTrends")
        case .detail(.nutrition):
            return InsightsLocalization.text("insights.action.exploreNutritionDetails")
        case .tab(.coach):
            return InsightsLocalization.text("insights.action.openCoach")
        case .tab(.today):
            return InsightsLocalization.text("insights.action.logToday")
        case .tab(.meals):
            return InsightsLocalization.text("insights.action.openNutrition")
        case .tab(.calendar):
            return InsightsLocalization.text("insights.action.openPlan")
//        case .tab(.highlights):
//            return "Open Highlights"
        case nil:
            return InsightsLocalization.text("insights.action.reviewDetails")
        }
    }

    static func storyConfidence(primaryDays: Int, pairedDays: Int) -> Double {
        let primary = min(Double(primaryDays) / 21.0, 1.0)
        let paired = min(Double(pairedDays) / 14.0, 1.0)
        return min(max(0.42 + primary * 0.34 + paired * 0.24, 0.35), 0.94)
    }

    static func hasEnoughStableContext(_ quality: InsightsDataQuality) -> Bool {
        quality.recoveryDays >= 14 ||
            quality.sleepDays >= 14 ||
            quality.activityDays >= 7 ||
            quality.mealDays >= 7
    }

    static func noMajorChangeHero(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsHeroInsight {
        let validRecovery = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let latest = validRecovery.last?.recoveryScore
        let graph = smoothedTrendValues(normalizedRecoveryValues(Array(validRecovery.suffix(30))))

        return InsightsHeroInsight(
            label: InsightsLocalization.Section.trend,
            title: InsightsLocalization.text("insights.fallback.stable.hero.title"),
            subtitle: InsightsLocalization.text("insights.fallback.stable.hero.subtitle"),
            takeaway: InsightsLocalization.text("insights.fallback.stable.hero.takeaway"),
            timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
            icon: "checkmark.seal.fill",
            accent: WeekFitTheme.meal,
            graphValues: graph,
            targetValue: latest == nil ? nil : 0.72,
            targetLabel: latest == nil ? nil : InsightsLocalization.text("insights.story.target.recovery72"),
            badgeValue: latest.map(String.init) ?? "—",
            badgeLabel: latest == nil
                ? InsightsLocalization.text("insights.story.badge.pattern")
                : InsightsLocalization.text("insights.story.badge.recovery"),
            domain: .consistency,
            actionDestination: .tab(.coach)
        )
    }

    static func missingDataHero(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsHeroInsight {
        InsightsHeroInsight(
            label: InsightsLocalization.Section.trend,
            title: InsightsLocalization.text("insights.fallback.baseline.hero.title"),
            subtitle: InsightsLocalization.text("insights.fallback.baseline.hero.subtitle"),
            takeaway: InsightsLocalization.text("insights.fallback.baseline.hero.takeaway"),
            timeframe: InsightsLocalization.text("insights.story.timeframe.last30Days"),
            icon: "brain.head.profile",
            accent: WeekFitTheme.meal,
            graphValues: [],
            badgeValue: "—",
            badgeLabel: InsightsLocalization.text("insights.story.badge.patterns"),
            domain: .missingData,
            actionDestination: .tab(.today)
        )
    }

    static func confidence(from quality: InsightsDataQuality) -> Double {
        let recovery = min(Double(quality.recoveryDays) / 7.0, 1.0)
        let sleep = min(Double(quality.sleepDays) / 7.0, 1.0)
        let food = min(Double(quality.mealDays) / 5.0, 1.0)
        let activity = min(Double(quality.activityDays) / 5.0, 1.0)
        return min(max(0.32 + recovery * 0.25 + sleep * 0.20 + food * 0.12 + activity * 0.11, 0.25), 0.92)
    }
}

private struct StoryTrainingVolumeSummary {
    let hours: Double
    let activeCalories: Int
    let sessions: Int

    var hasMeaningfulLoad: Bool {
        hours >= 1.0 || activeCalories >= 900 || sessions >= 2
    }

    var badgeValue: String {
        "\(String(format: "%.1f", hours))h"
    }
}

private extension InsightsStoryEngine {
    static func trainingVolumeSummary(_ records: [InsightsDayRecord]) -> StoryTrainingVolumeSummary {
        let hours = records.reduce(0.0) { total, record in
            let minutes = max(Double(record.metrics.exerciseMinutes), Double(record.completedWorkoutMinutes))
            return total + minutes / 60.0
        }
        let calories = records.reduce(0.0) { $0 + $1.metrics.activeCalories }
        let sessions = records.reduce(0) { $0 + $1.completedWorkoutCount }

        return StoryTrainingVolumeSummary(
            hours: hours,
            activeCalories: Int(calories.rounded()),
            sessions: sessions
        )
    }

    static func workloadSignificanceMetric(_ volume: StoryTrainingVolumeSummary) -> InsightTrendMetric {
        let change = workloadBaselineChange(volume)
        let direction: InsightTrendDirection = change > 8 ? .increasing : change < -8 ? .decreasing : .stable
        return InsightTrendMetric(
            label: InsightsLocalization.text("insights.signal.load"),
            value: InsightsLocalization.localizedWorkloadCategory(workloadCategory(volume)),
            direction: direction,
            detail: volume.badgeValue,
            benchmark: InsightsLocalization.text("insights.signal.recentBase")
        )
    }

    static func workloadCategory(_ volume: StoryTrainingVolumeSummary) -> String {
        if volume.hours < 1.0 && volume.activeCalories < 900 {
            return "Recovery Week"
        }
        if volume.hours >= 6.0 || volume.activeCalories >= 5_500 {
            return "High Load"
        }
        if volume.hours >= 3.0 || volume.activeCalories >= 2_800 {
            return "Solid Load"
        }
        return "Base Load"
    }

    static func workloadBaselineChange(_ volume: StoryTrainingVolumeSummary) -> Double {
        let hourRatio = volume.hours / 3.0
        let calorieRatio = Double(volume.activeCalories) / 2_800.0
        let sessionRatio = Double(volume.sessions) / 3.0
        return max(hourRatio, calorieRatio, sessionRatio) * 100.0
    }

    static func normalizedRecoveryValues(_ records: [InsightsDayRecord]) -> [Double] {
        records.map { record in
            record.recoveryScore > 0 ? Double(record.recoveryScore) / 100.0 : 0.18
        }
    }

    static func sleepScoreTrendValues(_ records: [InsightsDayRecord]) -> [Double] {
        smoothedTrendValues(Array(records.suffix(30)).map { record in
            Double(record.sleepScore) / 100.0
        })
    }

    static func sleepDurationTrendValues(_ records: [InsightsDayRecord]) -> [Double] {
        smoothedTrendValues(Array(records.suffix(30)).map { record in
            min(max(record.sleepHours / 8.0, 0), 1)
        })
    }

    static func smoothedTrendValues(_ values: [Double], maxPoints: Int = 10) -> [Double] {
        let valid = values.filter { $0 > 0 }
        guard valid.count > 2 else { return values }

        let chunkSize = max(1, Int(ceil(Double(valid.count) / Double(maxPoints))))
        var result: [Double] = []
        var index = 0
        while index < valid.count {
            let chunk = valid[index..<min(valid.count, index + chunkSize)]
            result.append(average(Array(chunk)))
            index += chunkSize
        }
        return result
    }

    static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func formatOneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

enum InsightsDomainIntelligenceEngine {
    static func pages(
        records recentRecords: [InsightsDayRecord],
        recoverySleepRecords analysisRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> [InsightsDomainPage] {
        let analysis = analysisRecords.isEmpty ? recentRecords : analysisRecords
        return [
            recoveryPage(records: recentRecords, analysisRecords: analysis, dataQuality: dataQuality),
            activityPage(records: recentRecords, analysisRecords: analysis, dataQuality: dataQuality),
            nutritionPage(records: recentRecords, analysisRecords: analysis, dataQuality: dataQuality)
        ]
    }
}

private extension InsightsDomainIntelligenceEngine {
    static func recoveryPage(
        records: [InsightsDayRecord],
        analysisRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> InsightsDomainPage {
        let recoveryRecords = analysisRecords.filter { $0.recoveryScore > 0 }
        guard !recoveryRecords.isEmpty else {
            return InsightsDomainPage.fallbackPages[0]
        }

        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDelta = baselineRecovery > 0 ? recentRecovery - baselineRecovery : 0
        let score = Int(recentRecovery.rounded())
        let sleepRecords = analysisRecords.filter { $0.sleepMinutes > 0 }
        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let baselineSleep = average(Array(sleepRecords.dropLast(7)).map(\.sleepHours))
        let sleepSpread = standardDeviation(Array(sleepRecords.suffix(14)).map(\.sleepHours))
        let recentHRV = average(Array(recoveryRecords.suffix(7)).map(\.metrics.hrvSDNN).filter { $0 > 0 })
        let baselineHRV = average(Array(recoveryRecords.dropLast(7)).map(\.metrics.hrvSDNN).filter { $0 > 0 })
        let recentRHR = average(Array(recoveryRecords.suffix(7)).map(\.metrics.restingHeartRate).filter { $0 > 0 })
        let baselineRHR = average(Array(recoveryRecords.dropLast(7)).map(\.metrics.restingHeartRate).filter { $0 > 0 })
        let loadRecent = average(Array(analysisRecords.suffix(7)).map(\.activityLoadScore))
        let loadBaseline = average(Array(analysisRecords.dropLast(7)).map(\.activityLoadScore))
        let sleepConsistency = consistencyPercent(Array(sleepRecords.suffix(14)).map(\.sleepHours), tolerance: 0.65)

        let trend: String
        if recoveryDelta <= -4 {
            trend = InsightsLocalization.text("insights.domain.recovery.trend.needsAttention")
        } else if score >= 72, recentSleep > 0, recentSleep < 7 {
            trend = InsightsLocalization.text("insights.domain.recovery.trend.resilient")
        } else if score >= 72, loadRecent >= loadBaseline + 10 {
            trend = InsightsLocalization.text("insights.domain.recovery.trend.resilient")
        } else if recoveryDelta >= 4 {
            trend = InsightsLocalization.text("insights.domain.recovery.trend.improving")
        } else if score >= 72 {
            trend = InsightsLocalization.text("insights.domain.recovery.trend.stable")
        } else {
            trend = InsightsLocalization.text("insights.domain.recovery.trend.needsSupport")
        }

        let takeaway: String
        if recentSleep > 0, recentSleep < 7, score >= 72 {
            takeaway = InsightsLocalization.text("insights.domain.recovery.takeaway.sleepLower")
        } else if sleepSpread >= 0.55 {
            takeaway = InsightsLocalization.text("insights.domain.recovery.takeaway.sleepVariability")
        } else if recentHRV > 0, baselineHRV > 0, recentHRV >= baselineHRV + 4 {
            takeaway = InsightsLocalization.text("insights.domain.recovery.takeaway.hrv")
        } else if recentRHR > 0, baselineRHR > 0, recentRHR <= baselineRHR - 3 {
            takeaway = InsightsLocalization.text("insights.domain.recovery.takeaway.rhr")
        } else if loadRecent > loadBaseline + 10 {
            takeaway = InsightsLocalization.text("insights.domain.recovery.takeaway.loadIncrease")
        } else {
            takeaway = InsightsLocalization.text("insights.domain.recovery.takeaway.aligned")
        }

        let focus: String
        if recoveryDelta <= -4 {
            focus = InsightsLocalization.text("insights.domain.recovery.focus.recoveryDay")
        } else if recentSleep > 0, recentSleep < 7 {
            focus = InsightsLocalization.text("insights.domain.recovery.focus.sleepConsistency")
        } else if loadRecent > loadBaseline + 10 {
            focus = InsightsLocalization.text("insights.domain.recovery.focus.maintainLoad")
        } else {
            focus = InsightsLocalization.text("insights.domain.recovery.focus.maintainApproach")
        }

        let chartValues = smoothedValues(recoveryRecords.map { Double($0.recoveryScore) / 100.0 })
        return validatedMonthlyReviewPage(
            InsightsDomainPage(
            id: "domain.recovery",
            domain: .recovery,
            label: InsightsLocalization.Section.recovery,
            title: InsightsLocalization.text("insights.domain.recovery.title"),
            scoreValue: "\(score)",
            statusText: InsightsLocalization.statusText(for: score),
            headline: trend,
            chartValues: chartValues,
            chartTarget: 0.72,
            chartTargetLabel: InsightsLocalization.text("insights.domain.chartTargetRange"),
            keySignals: [
                InsightsKeySignal(
                    id: "recovery.sleep",
                    label: InsightsLocalization.text("insights.domain.recovery.signal.sleepSupports.label"),
                    value: recentSleep >= 7
                        ? InsightsLocalization.text("insights.domain.recovery.signal.sleepSupports.healthy")
                        : InsightsLocalization.text("insights.domain.recovery.signal.sleepSupports.opportunity")
                ),
                InsightsKeySignal(
                    id: "recovery.stability",
                    label: InsightsLocalization.text("insights.domain.recovery.signal.stabilized.label"),
                    value: recoveryDelta >= -3
                        ? InsightsLocalization.text("insights.domain.recovery.signal.stabilized.positive")
                        : InsightsLocalization.text("insights.domain.recovery.signal.stabilized.negative")
                ),
                InsightsKeySignal(
                    id: "recovery.load",
                    label: InsightsLocalization.text("insights.domain.recovery.signal.noOverload.label"),
                    value: loadRecent <= loadBaseline + 10
                        ? InsightsLocalization.text("insights.domain.recovery.signal.noOverload.resilient")
                        : InsightsLocalization.text("insights.domain.recovery.signal.noOverload.absorbing")
                )
            ],
            standoutText: takeaway,
            focusText: focus,
            icon: "heart.fill",
            accent: Color(red: 0.18, green: 0.74, blue: 0.89)
            ),
            score: score
        )
    }

    static func activityPage(
        records: [InsightsDayRecord],
        analysisRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> InsightsDomainPage {
        let activityRecords = analysisRecords.filter(\.hasActivitySignal)
        guard !activityRecords.isEmpty else {
            return InsightsDomainPage.fallbackPages[1]
        }

        let recent = Array(analysisRecords.suffix(7))
        let baseline = Array(analysisRecords.dropLast(7))
        let recentLoad = average(recent.map(\.activityLoadScore))
        let baselineLoad = average(baseline.map(\.activityLoadScore))
        let loadDelta = baselineLoad > 0 ? recentLoad - baselineLoad : 0
        let recentSessions = recent.reduce(0) { $0 + $1.completedWorkoutCount }
        let baselineSessions = averageSessionCountPerWeek(baseline)
        let activeEnergyRecent = average(recent.map(\.metrics.activeCalories).filter { $0 > 0 })
        let activeEnergyBaseline = average(baseline.map(\.metrics.activeCalories).filter { $0 > 0 })
        let exerciseRecent = average(recent.map { Double($0.metrics.exerciseMinutes) }.filter { $0 > 0 })
        let exerciseBaseline = average(baseline.map { Double($0.metrics.exerciseMinutes) }.filter { $0 > 0 })
        let standRecent = average(recent.map { Double($0.metrics.standHours) }.filter { $0 > 0 })
        let standBaseline = average(baseline.map { Double($0.metrics.standHours) }.filter { $0 > 0 })
        let recoveryRecent = average(Array(analysisRecords.filter { $0.recoveryScore > 0 }.suffix(7)).map { Double($0.recoveryScore) })
        let score = Int(min(max((recentLoad * 0.72) + min(Double(recentSessions) / 4.0, 1) * 18 + min(standRecent / 10.0, 1) * 10, 0), 100).rounded())
        let loadPercentChange = baselineLoad > 0 ? (loadDelta / baselineLoad) * 100 : 0

        let trend: String
        if loadPercentChange >= 15, recoveryRecent >= 72 {
            trend = InsightsLocalization.text("insights.domain.activity.trend.sustainableProgress")
        } else if loadPercentChange >= 15 {
            trend = InsightsLocalization.text("insights.domain.activity.trend.needsRestraint")
        } else if loadPercentChange <= -18 {
            trend = InsightsLocalization.text("insights.domain.activity.trend.baseFading")
        } else if score >= 75 {
            trend = InsightsLocalization.text("insights.domain.activity.trend.inBalance")
        } else {
            trend = InsightsLocalization.text("insights.domain.activity.trend.baseBuilding")
        }

        let takeaway: String
        if Double(recentSessions) >= baselineSessions + 1.0, baselineSessions > 0 {
            takeaway = InsightsLocalization.text("insights.domain.activity.takeaway.rhythm")
        } else if activeEnergyRecent > 0, activeEnergyBaseline > 0, activeEnergyRecent <= activeEnergyBaseline * 0.80 {
            takeaway = InsightsLocalization.text("insights.domain.activity.takeaway.movementSoftened")
        } else if loadPercentChange >= 15, recoveryRecent < 72 {
            takeaway = InsightsLocalization.text("insights.domain.activity.takeaway.loadFaster")
        } else if standRecent > 0, standBaseline > 0, standRecent >= standBaseline + 1.0 {
            takeaway = InsightsLocalization.text("insights.domain.activity.takeaway.movementSupported")
        } else {
            takeaway = InsightsLocalization.text("insights.domain.activity.takeaway.matched")
        }

        let focus: String
        if loadPercentChange >= 15, recoveryRecent >= 72 {
            focus = InsightsLocalization.text("insights.domain.recovery.focus.maintainLoad")
        } else if loadPercentChange >= 15 {
            focus = InsightsLocalization.text("insights.domain.activity.focus.reduceVolume")
        } else if activeEnergyRecent > 0, activeEnergyBaseline > 0, activeEnergyRecent <= activeEnergyBaseline * 0.80 {
            focus = InsightsLocalization.text("insights.domain.activity.focus.increaseMovement")
        } else {
            focus = InsightsLocalization.text("insights.domain.recovery.focus.maintainApproach")
        }

        let chartValues = smoothedValues(analysisRecords.map { record in
            let load = min(max(record.activityLoadScore / 100.0, 0), 1)
            guard load > 0 else { return 0 }

            if load > 0.70 {
                let recoveryScore = Double(record.recoveryScore)
                if recoveryScore >= 72 || recoveryRecent >= 72 {
                    return min(0.68, 0.62 + (load - 0.70) * 0.20)
                }

                return min(load, 0.92)
            }

            return load
        })
        return validatedMonthlyReviewPage(
            InsightsDomainPage(
            id: "domain.activity",
            domain: .activity,
            label: InsightsLocalization.Section.activity,
            title: InsightsLocalization.text("insights.domain.activity.title"),
            scoreValue: "\(score)",
            statusText: InsightsLocalization.statusText(for: score),
            headline: trend,
            chartValues: chartValues,
            chartTarget: 0.70,
            chartTargetLabel: InsightsLocalization.text("insights.domain.chartSustainableLoad"),
            keySignals: [
                InsightsKeySignal(
                    id: "activity.consistency",
                    label: InsightsLocalization.text("insights.domain.activity.signal.consistency.label"),
                    value: InsightsLocalization.text("insights.domain.activity.signal.consistency.value")
                ),
                InsightsKeySignal(
                    id: "activity.load",
                    label: InsightsLocalization.text("insights.domain.activity.signal.load.label"),
                    value: loadPercentChange >= 15
                        ? InsightsLocalization.text("insights.domain.activity.signal.load.increased")
                        : InsightsLocalization.text("insights.domain.activity.signal.load.controlled")
                ),
                InsightsKeySignal(
                    id: "activity.recovery",
                    label: InsightsLocalization.text("insights.domain.activity.signal.recovery.label"),
                    value: recoveryRecent >= 72
                        ? InsightsLocalization.text("insights.domain.activity.signal.recovery.noFatigue")
                        : InsightsLocalization.text("insights.domain.activity.signal.recovery.needsRoom")
                )
            ],
            standoutText: takeaway,
            focusText: focus,
            icon: "figure.run",
            accent: Color(red: 0.16, green: 0.80, blue: 0.43)
            ),
            score: score
        )
    }

    static func nutritionPage(
        records: [InsightsDayRecord],
        analysisRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> InsightsDomainPage {
        let nutritionRecords = analysisRecords.filter { $0.mealCount > 0 || $0.proteinGrams > 0 || $0.waterLiters > 0 || $0.calories > 0 }
        guard !nutritionRecords.isEmpty else {
            return InsightsDomainPage.fallbackPages[2]
        }

        let proteinGoal = analysisRecords.last?.nutritionGoals?.protein ?? records.last?.nutritionGoals?.protein ?? 0
        let calorieGoal = analysisRecords.last?.nutritionGoals?.calories ?? records.last?.nutritionGoals?.calories ?? 0
        let waterGoal = analysisRecords.last?.nutritionGoals?.waterLiters ?? records.last?.nutritionGoals?.waterLiters ?? 0
        let averageProtein = average(nutritionRecords.map(\.proteinGrams).filter { $0 > 0 })
        let averageCalories = average(nutritionRecords.map(\.calories).filter { $0 > 0 })
        let averageWater = average(nutritionRecords.map(\.waterLiters).filter { $0 > 0 })
        let proteinRatio = proteinGoal > 0 ? averageProtein / proteinGoal : 0
        let calorieAlignment = calorieGoal > 0 && averageCalories > 0 ? max(0, 1 - abs(averageCalories - calorieGoal) / calorieGoal) : 0
        let hydrationRatio = waterGoal > 0 ? averageWater / waterGoal : 0
        let mealConsistency = min(Double(nutritionRecords.filter { $0.mealCount > 0 }.count) / 21.0, 1.0)
        let score = Int(min(max(proteinRatio * 40 + calorieAlignment * 28 + min(hydrationRatio, 1) * 22 + mealConsistency * 10, 0), 100).rounded())
        let recentNutrition = Array(nutritionRecords.suffix(7))
        let baselineNutrition = Array(nutritionRecords.dropLast(7))
        let recentCalories = average(recentNutrition.map(\.calories).filter { $0 > 0 })
        let baselineCalories = average(baselineNutrition.map(\.calories).filter { $0 > 0 })
        let baselineProtein = average(baselineNutrition.map(\.proteinGrams).filter { $0 > 0 })
        let recentWater = average(recentNutrition.map(\.waterLiters).filter { $0 > 0 })
        let baselineWater = average(baselineNutrition.map(\.waterLiters).filter { $0 > 0 })

        let trend: String
        if proteinGoal > 0, proteinRatio < 0.80 {
            trend = InsightsLocalization.text("insights.domain.nutrition.trend.proteinOpportunity")
        } else if calorieAlignment >= 0.85, proteinRatio >= 0.85 {
            trend = InsightsLocalization.text("insights.domain.nutrition.trend.supportsTraining")
        } else if waterGoal > 0, hydrationRatio < 0.75 {
            trend = InsightsLocalization.text("insights.domain.nutrition.trend.hydrationImproving")
        } else if mealConsistency < 0.45 {
            trend = InsightsLocalization.text("insights.domain.nutrition.trend.becomingConsistent")
        } else {
            trend = InsightsLocalization.text("insights.domain.nutrition.trend.inBalance")
        }

        let takeaway: String
        if proteinGoal > 0, proteinRatio < 0.80 {
            takeaway = InsightsLocalization.text("insights.domain.nutrition.takeaway.protein")
        } else if waterGoal > 0, hydrationRatio < 0.75 {
            takeaway = InsightsLocalization.text("insights.domain.nutrition.takeaway.hydration")
        } else if calorieAlignment >= 0.85 {
            takeaway = InsightsLocalization.text("insights.domain.nutrition.takeaway.energy")
        } else if mealConsistency < 0.45 {
            takeaway = InsightsLocalization.text("insights.domain.nutrition.takeaway.mealLogging")
        } else {
            takeaway = InsightsLocalization.text("insights.domain.nutrition.takeaway.strong")
        }

        let focus: String
        if proteinGoal > 0, proteinRatio < 0.80 {
            focus = InsightsLocalization.text("insights.domain.nutrition.focus.increaseProtein")
        } else if waterGoal > 0, hydrationRatio < 0.75 {
            focus = InsightsLocalization.text("insights.domain.nutrition.focus.hydration")
        } else if mealConsistency < 0.45 {
            focus = InsightsLocalization.text("insights.domain.nutrition.focus.logWeek")
        } else {
            focus = InsightsLocalization.text("insights.domain.recovery.focus.maintainApproach")
        }

        let chartValues = smoothedValues(nutritionRecords.map { record in
            if proteinGoal > 0 {
                return min(max(record.proteinGrams / proteinGoal, 0), 1)
            }
            return record.mealCount > 0 ? 0.70 : 0.20
        })
        return validatedMonthlyReviewPage(
            InsightsDomainPage(
            id: "domain.nutrition",
            domain: .nutrition,
            label: InsightsLocalization.Section.nutrition,
            title: InsightsLocalization.text("insights.domain.nutrition.title"),
            scoreValue: "\(score)",
            statusText: InsightsLocalization.statusText(for: score),
            headline: trend,
            chartValues: chartValues,
            chartTarget: 0.80,
            chartTargetLabel: InsightsLocalization.text("insights.domain.chartTargetRange"),
            keySignals: [
                InsightsKeySignal(
                    id: "nutrition.protein",
                    label: InsightsLocalization.text("insights.domain.nutrition.signal.protein.label"),
                    value: proteinRatio < 0.80
                        ? InsightsLocalization.text("insights.domain.nutrition.signal.protein.below")
                        : InsightsLocalization.text("insights.domain.nutrition.signal.protein.reliable")
                ),
                InsightsKeySignal(
                    id: "nutrition.quality",
                    label: InsightsLocalization.text("insights.domain.nutrition.signal.quality.label"),
                    value: mealConsistency >= 0.45
                        ? InsightsLocalization.text("insights.domain.nutrition.signal.quality.reliable")
                        : InsightsLocalization.text("insights.domain.nutrition.signal.quality.moreMeals")
                ),
                InsightsKeySignal(
                    id: "nutrition.recovery",
                    label: InsightsLocalization.text("insights.domain.nutrition.signal.recovery.label"),
                    value: score >= 72
                        ? InsightsLocalization.text("insights.domain.nutrition.signal.recovery.strong")
                        : InsightsLocalization.text("insights.domain.nutrition.signal.recovery.limiter")
                )
            ],
            standoutText: takeaway,
            focusText: focus,
            icon: "fork.knife",
            accent: Color(red: 0.95, green: 0.65, blue: 0.12)
            ),
            score: score
        )
    }

    static func statusText(for score: Int) -> String {
        InsightsLocalization.statusText(for: score)
    }

    static func directionSymbol(current: Double, baseline: Double, lowerIsBetter: Bool = false) -> String {
        guard baseline > 0 else { return "→" }
        let delta = current - baseline
        guard abs(delta) >= 0.1 else { return "→" }
        if lowerIsBetter {
            return delta < 0 ? "↓" : "↑"
        }
        return delta > 0 ? "↑" : "↓"
    }

    static func validatedMonthlyReviewPage(_ page: InsightsDomainPage, score: Int) -> InsightsDomainPage {
        let softSignals = page.keySignals.filter { signalSuggestsPressure($0) }.count
        let supportiveSignals = page.keySignals.filter { signalSuggestsSupport($0) }.count
        let chartDelta = chartSlope(page.chartValues)
        let tooPositiveForSignals = score >= 72 && softSignals >= 3 && chartDelta < 0
        let tooNegativeForSignals = score < 60 && supportiveSignals >= 3 && chartDelta > 0

        guard tooPositiveForSignals || tooNegativeForSignals else {
            return page
        }

        let headline: String
        let takeaway: String
        let focus: String
        switch page.domain {
        case .recovery:
            headline = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.recovery.validation.strongDespiteSoft")
                : InsightsLocalization.text("insights.domain.recovery.validation.improvingNeedsSupport")
            takeaway = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.recovery.validation.strongTakeaway")
                : InsightsLocalization.text("insights.domain.recovery.validation.improvingTakeaway")
            focus = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.recovery.focus.maintainApproach")
                : InsightsLocalization.text("insights.domain.recovery.focus.sleepConsistency")
        case .activity:
            headline = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.activity.validation.strongDespiteMovement")
                : InsightsLocalization.text("insights.domain.activity.validation.rebuilding")
            takeaway = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.activity.validation.strongTakeaway")
                : InsightsLocalization.text("insights.domain.activity.validation.rebuildingTakeaway")
            focus = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.recovery.focus.maintainLoad")
                : InsightsLocalization.text("insights.domain.activity.focus.increaseMovement")
        case .nutrition:
            headline = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.nutrition.validation.strongDespiteInputs")
                : InsightsLocalization.text("insights.domain.nutrition.validation.improvingLimited")
            takeaway = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.nutrition.validation.strongTakeaway")
                : InsightsLocalization.text("insights.domain.nutrition.validation.improvingTakeaway")
            focus = tooPositiveForSignals
                ? InsightsLocalization.text("insights.domain.recovery.focus.maintainApproach")
                : InsightsLocalization.text("insights.domain.nutrition.focus.increaseProtein")
        default:
            return page
        }

        return InsightsDomainPage(
            id: page.id,
            domain: page.domain,
            label: page.label,
            title: page.title,
            scoreValue: page.scoreValue,
            statusText: page.statusText,
            headline: headline,
            chartValues: page.chartValues,
            chartTarget: page.chartTarget,
            chartTargetLabel: page.chartTargetLabel,
            keySignals: page.keySignals,
            standoutText: takeaway,
            focusText: focus,
            icon: page.icon,
            accent: page.accent
        )
    }

    static func signalSuggestsPressure(_ signal: InsightsKeySignal) -> Bool {
        let trimmed = signal.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if signal.label == "RHR", trimmed.contains("↑") { return true }
        return trimmed.contains("↓") || trimmed.hasPrefix("-") || trimmed == "Limited"
    }

    static func signalSuggestsSupport(_ signal: InsightsKeySignal) -> Bool {
        let trimmed = signal.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if signal.label == "RHR", trimmed.contains("↓") { return true }
        if signal.label == "RHR", trimmed.contains("↑") { return false }
        return trimmed.contains("↑") || trimmed.hasPrefix("+") || trimmed == "OK" || trimmed == "Stable"
    }

    static func chartSlope(_ values: [Double]) -> Double {
        guard let first = values.first, let last = values.last else { return 0 }
        return last - first
    }

    static func signedPercentChange(current: Double, baseline: Double) -> String {
        guard baseline > 0, current > 0 else { return "—" }
        let change = ((current - baseline) / baseline) * 100
        return signedPercentValue(change)
    }

    static func signedPercentValue(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return "\(value >= 0 ? "+" : "")\(Int(value.rounded()))%"
    }

    static func signedDecimal(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let rounded = (value * 10).rounded() / 10
        return "\(rounded >= 0 ? "+" : "")\(formatOneDecimal(rounded))"
    }

    static func signedHoursChange(currentMinutes: Double, baselineMinutes: Double) -> String {
        guard currentMinutes > 0, baselineMinutes > 0 else { return "—" }
        return "\(signedDecimal((currentMinutes - baselineMinutes) / 60.0))h"
    }

    static func signedGrams(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return "\(value >= 0 ? "+" : "")\(Int(value.rounded()))g"
    }

    static func formatOneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func consistencyPercent(_ values: [Double], tolerance: Double) -> Double {
        let valid = values.filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        let mean = average(valid)
        let consistent = valid.filter { abs($0 - mean) <= tolerance }.count
        return (Double(consistent) / Double(valid.count)) * 100
    }

    static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = average(values)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }

    static func averageSessionCountPerWeek(_ records: [InsightsDayRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        let weeks = max(Double(records.count) / 7.0, 1.0)
        let sessions = records.reduce(0) { $0 + $1.completedWorkoutCount }
        return Double(sessions) / weeks
    }

    static func smoothedValues(_ values: [Double], maxPoints: Int = 10) -> [Double] {
        let valid = values.filter { $0 > 0 }
        guard valid.count > 2 else { return values }

        let chunkSize = max(1, Int(ceil(Double(valid.count) / Double(maxPoints))))
        var result: [Double] = []
        var index = 0
        while index < valid.count {
            let chunk = valid[index..<min(valid.count, index + chunkSize)]
            result.append(average(Array(chunk)))
            index += chunkSize
        }
        return result
    }
}
