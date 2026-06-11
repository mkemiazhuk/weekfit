import XCTest
@testable import WeekFit

final class InsightsSnapshotModelTests: XCTestCase {

    func testFallbackSnapshotExposesEvidenceAndCoverageState() {
        let snapshot = InsightsSnapshot.fallback

        XCTAssertEqual(snapshot.evidence.label, "WHY THIS")
        XCTAssertEqual(snapshot.evidence.confidenceLabel, "Building")
        XCTAssertFalse(snapshot.evidence.bullets.isEmpty)
        XCTAssertFalse(snapshot.whyItems.isEmpty)
        XCTAssertLessThanOrEqual(snapshot.whyItems.count, 3)
        XCTAssertFalse(snapshot.nextActions.isEmpty)
        XCTAssertLessThanOrEqual(snapshot.nextActions.count, 3)
        XCTAssertFalse(snapshot.dataQuality.hasAnySignal)
        XCTAssertFalse(snapshot.learnings.isEmpty)
        XCTAssertNotNil(snapshot.opportunity)
    }

    func testSnapshotPreservesInsightContextSections() {
        let snapshot = InsightsSnapshot(
            avatarInitials: "WF",
            weekDays: ["M", "T", "W", "T", "F", "S", "S"],
            hero: InsightsHeroInsight(
                label: "TODAY'S READ",
                title: "Recovery is the clearest read",
                subtitle: "Recovery is shaping the current pattern after a demanding training week.",
                takeaway: "Watch how recovery responds after harder sessions.",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: [0.70, 0.66, 0.61, 0.58],
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "58",
                badgeLabel: "recovery",
                domain: .recovery
            ),
            whyItems: [
                InsightsWhyItem(
                    title: "Recovery is under strain",
                    value: "58",
                    detail: "Readiness is low enough to favor restraint.",
                    icon: "heart.fill",
                    domain: .recovery
                )
            ],
            nextActions: [
                InsightsNextAction(
                    title: "Watch recovery before adding load",
                    detail: "Compare readiness after harder days this week.",
                    icon: "heart.fill",
                    destination: .detail(.recovery)
                )
            ],
            weeklyScores: [],
            trends: [],
            hydrationImpact: InsightsCorrelationCard(label: "", title: "", subtitle: "", rows: [], domain: .recovery, actionDestination: nil),
            weeklyReflection: InsightsReflection(label: "", text: "", domain: .recovery),
            focusNext: InsightsFocusNext(label: "", title: "", text: "", action: "", icon: "heart.fill", accent: WeekFitTheme.meal, domain: .recovery),
            dataQuality: InsightsDataQuality(
                recoveryDays: 7,
                sleepDays: 7,
                hydrationDays: 2,
                mealDays: 5,
                activityDays: 6,
                plannerDays: 7
            )
        )

        XCTAssertEqual(snapshot.hero.domain, .recovery)
        XCTAssertEqual(snapshot.whyItems.map(\.domain), [.recovery])
        XCTAssertEqual(snapshot.nextActions.first?.title, "Watch recovery before adding load")
        XCTAssertFalse(snapshot.hero.title.lowercased().contains("leads the day"))
    }

    func testHeroCanCarryTimeframeAndReferenceLine() {
        let hero = InsightsHeroInsight(
            label: "MAIN SIGNAL",
            title: "Sleep is limiting recovery",
            subtitle: "Recovery remains strong, but sleep is consistently below target.",
            takeaway: "Protect sleep before adding load.",
            timeframe: "Last 7 days",
            icon: "moon.fill",
            accent: WeekFitTheme.purple,
            graphValues: [0.68, 0.74, 0.70, 0.76],
            targetValue: 7.0 / 8.0,
            targetLabel: "7h target",
            badgeValue: "6.4h avg",
            badgeLabel: "Last 7 days",
            domain: .sleep
        )

        XCTAssertEqual(hero.timeframe, "Last 7 days")
        XCTAssertEqual(hero.targetLabel, "7h target")
        XCTAssertEqual(hero.badgeValue, "6.4h avg")
        if case .trendLine(_, let target, let targetLabel) = hero.visualization {
            XCTAssertEqual(target, 7.0 / 8.0)
            XCTAssertEqual(targetLabel, "7h target")
        } else {
            XCTFail("Default hero visualization should remain a trend line")
        }
    }

    func testHeroCanChooseNonSleepSpecificVisualization() {
        let hero = InsightsHeroInsight(
            label: "MAIN SIGNAL",
            title: "Training volume is your biggest opportunity",
            subtitle: "Recovery is available, but weekly workload is still below a base-building threshold.",
            takeaway: "Add one low-risk hour first.",
            timeframe: "Last 7 days",
            icon: "figure.run",
            accent: WeekFitTheme.orange,
            graphValues: [0.2, 0.8, 0.2, 0.2, 0.8, 0.2, 0.2],
            visualization: .consistency(
                values: [true, false, false, true, false, false, false],
                positiveLabel: "active",
                negativeLabel: "open"
            ),
            badgeValue: "low",
            badgeLabel: "weekly load",
            domain: .activity
        )

        if case .consistency(let values, let positiveLabel, let negativeLabel) = hero.visualization {
            XCTAssertEqual(values.filter { $0 }.count, 2)
            XCTAssertEqual(positiveLabel, "active")
            XCTAssertEqual(negativeLabel, "open")
        } else {
            XCTFail("Hero should support non-line visualizations")
        }
    }

    func testHeroSupportsPremiumVisualizationVariants() {
        let variants: [InsightVisualization] = [
            .relationshipGraph(
                primary: [0.8, 0.7, 0.6],
                secondary: [0.3, 0.5, 0.7],
                insightLabel: "inverse pattern"
            ),
            .trendChange(
                before: [0.4, 0.35, 0.3],
                after: [0.32, 0.45, 0.58],
                label: "trend reversal"
            ),
            .signalStrength(strength: 0.82, label: "strong signal")
        ]

        XCTAssertEqual(variants.count, 3)
        if case .signalStrength(let strength, let label) = variants[2] {
            XCTAssertEqual(strength, 0.82)
            XCTAssertEqual(label, "strong signal")
        } else {
            XCTFail("Signal strength variant should remain available")
        }
    }

    func testEvidenceUsesHumanConfidenceLanguage() {
        let evidence = InsightsEvidence(
            label: "WHY THIS READ",
            confidenceLabel: "High",
            confidenceValue: 0.86,
            sourceSummary: "Based on consistent sleep history, consistent recovery history, a full recent training week and limited nutrition data.",
            recencyText: "Based on recent training history",
            bullets: [
                "A full recent training week is available, so load can be interpreted as a pattern.",
                "Recovery context shows whether that load is being absorbed or merely completed."
            ]
        )

        XCTAssertTrue(evidence.sourceSummary.contains("consistent sleep history"))
        XCTAssertFalse(evidence.sourceSummary.contains("/30"))
        XCTAssertFalse(evidence.sourceSummary.contains("sleep nights"))
        XCTAssertFalse(evidence.bullets.joined(separator: " ").contains("days are available"))
    }

    func testInsightScenarioLibraryCoversEveryInsightClass() {
        #if DEBUG
        let coveredClasses = Set(InsightsSnapshot.insightScenarioLibrary.map(\.insightClass))

        XCTAssertGreaterThanOrEqual(InsightsSnapshot.insightScenarioLibrary.count, 20)
        XCTAssertEqual(
            coveredClasses,
            Set(InsightScenarioClass.allCases),
            "Every engine insight class must have at least one scenario in the gallery regression suite."
        )
        #endif
    }

    func testInsightScenariosDeclareCompleteExpectedOutputs() {
        #if DEBUG
        for scenario in InsightsSnapshot.insightScenarioLibrary {
            XCTAssertFalse(scenario.name.isEmpty)
            XCTAssertFalse(scenario.triggerConditions.isEmpty, scenario.name)
            XCTAssertFalse(scenario.expectedHero.title.isEmpty, scenario.name)
            XCTAssertEqual(scenario.expectedHero.visualization.kind, scenario.expectedVisualizationType, scenario.name)
            XCTAssertFalse(scenario.expectedEvidence.bullets.isEmpty, scenario.name)
            XCTAssertFalse(scenario.expectedSupportCards.isEmpty, scenario.name)
            XCTAssertFalse(scenario.expectedLearnings.isEmpty, scenario.name)
            XCTAssertFalse(scenario.expectedOpportunity.title.isEmpty, scenario.name)

            let snapshot = scenario.snapshot
            XCTAssertEqual(snapshot.hero.title, scenario.expectedHero.title, scenario.name)
            XCTAssertEqual(snapshot.hero.visualization.kind, scenario.expectedVisualizationType, scenario.name)
            XCTAssertEqual(snapshot.evidence.bullets, scenario.expectedEvidence.bullets, scenario.name)
            XCTAssertEqual(snapshot.supportCards.count, scenario.expectedSupportCards.count, scenario.name)
            XCTAssertEqual(snapshot.learnings.count, scenario.expectedLearnings.count, scenario.name)
            XCTAssertEqual(snapshot.opportunity?.title, scenario.expectedOpportunity.title, scenario.name)
        }
        #endif
    }

    func testScenarioSupportCardsFollowHeroInsightType() {
        #if DEBUG
        for scenario in InsightsSnapshot.insightScenarioLibrary {
            let roles = Set(scenario.expectedSupportCards.map(\.role))
            switch scenario.expectedHero.insightType {
            case .sleep:
                XCTAssertFalse(roles.isDisjoint(with: [.strongestPattern, .bottleneck, .relationship, .experiment]), scenario.name)
            case .training:
                XCTAssertFalse(roles.isDisjoint(with: [.workload, .adaptation, .progression, .risk]), scenario.name)
            case .recovery:
                XCTAssertFalse(roles.isDisjoint(with: [.resilience, .limitingFactor, .recoveryDriver, .opportunity]), scenario.name)
            case .nutrition, .hydration, .consistency, .missingData:
                XCTAssertFalse(roles.isEmpty, scenario.name)
            }
        }
        #endif
    }

    func testScenarioSupportCardsDoNotRepeatDomains() {
        #if DEBUG
        for scenario in InsightsSnapshot.insightScenarioLibrary {
            let domains = scenario.expectedSupportCards.map(\.domain)
            XCTAssertEqual(
                domains.count,
                Set(domains).count,
                "\(scenario.name) repeats a support-card domain instead of explaining the hero through cross-domain evidence."
            )
        }
        #endif
    }

    func testSupportCardsUseCoachLanguageAndMeasurableExperiments() {
        #if DEBUG
        let allCards = InsightsSnapshot.insightScenarioLibrary.flatMap(\.expectedSupportCards)
        let supportText = allCards
            .map { card in
                ([card.title, card.text] + card.metrics.flatMap { [$0.label, $0.value, $0.detail, $0.benchmark] }).joined(separator: " ")
            }
            .joined(separator: " ")
            .lowercased()

        let bannedAnalyticsTerms = [
            "state:",
            "trend:",
            "baseline",
            "confidence",
            "correlation",
            "relationship",
            "delta",
            "variance"
        ]

        for term in bannedAnalyticsTerms {
            XCTAssertFalse(supportText.contains(term), "Support cards expose analytics language: \(term)")
        }

        let experiments = allCards.filter { $0.role == .experiment }
        for experiment in experiments {
            let text = ([experiment.title, experiment.text] + experiment.metrics.map(\.label)).joined(separator: " ").lowercased()
            XCTAssertTrue(text.contains("try") || text.contains("go to bed") || text.contains("anchor") || text.contains("prioritize"), experiment.title)
            XCTAssertTrue(text.contains("look for") || text.contains("should"), experiment.title)
            XCTAssertTrue(text.contains("review"), experiment.title)
        }
        #endif
    }

    func testNutritionSupportIsNotGenericFiller() {
        #if DEBUG
        for scenario in InsightsSnapshot.insightScenarioLibrary {
            let nutritionCards = scenario.expectedSupportCards.filter { $0.domain == .nutrition }
            for card in nutritionCards {
                let text = ([card.title, card.text] + card.metrics.map(\.benchmark)).joined(separator: " ").lowercased()
                XCTAssertTrue(
                    text.contains("protein") || text.contains("nutrition") || text.contains("meal") || text.contains("target"),
                    "\(scenario.name) has nutrition support without nutrition meaning."
                )
            }
        }
        #endif
    }

    func testScenarioLibraryAvoidsDashboardLanguage() {
        #if DEBUG
        let bannedTerms = [
            "state:",
            "trend:",
            "baseline",
            "confidence",
            "correlation",
            "relationship",
            "delta",
            "variance"
        ]

        for scenario in InsightsSnapshot.insightScenarioLibrary {
            let text = [
                scenario.expectedHero.title,
                scenario.expectedHero.subtitle,
                scenario.expectedHero.takeaway,
                scenario.expectedHero.badgeLabel,
                scenario.expectedEvidence.label,
                scenario.expectedEvidence.sourceSummary,
                scenario.expectedEvidence.recencyText,
                scenario.expectedEvidence.bullets.joined(separator: " "),
                scenario.expectedSupportCards.map { card in
                    ([card.title, card.text] + card.metrics.flatMap { [$0.label, $0.value, $0.detail, $0.benchmark] }).joined(separator: " ")
                }.joined(separator: " "),
                scenario.expectedLearnings.map(\.text).joined(separator: " "),
                scenario.expectedOpportunity.title,
                scenario.expectedOpportunity.text
            ]
            .joined(separator: " ")
            .lowercased()

            for term in bannedTerms {
                XCTAssertFalse(text.contains(term), "\(scenario.name) exposes dashboard language: \(term)")
            }
        }
        #endif
    }

    func testTrainingScenariosExplainLoadNotFrequencyAlone() {
        #if DEBUG
        let trainingClasses: Set<InsightScenarioClass> = [
            .trainingConsistency,
            .overtrainingRisk,
            .trainingFrequency,
            .activeCalorieTrend,
            .loadManagement,
            .cardioFitness,
            .stressAccumulation
        ]
        let bannedPhrases = [
            "active days",
            "training showed up",
            "training exposure",
            "training frequency",
            "full 7 days",
            "10006",
            "25 sessions"
        ]
        let requiredConcepts = [
            "recovery week",
            "light week",
            "normal week",
            "productive week",
            "heavy week",
            "very high load week",
            "load",
            "workload",
            "recovery",
            "adaptation",
            "intensity"
        ]

        for scenario in InsightsSnapshot.insightScenarioLibrary where trainingClasses.contains(scenario.insightClass) {
            let text = [
                scenario.expectedHero.title,
                scenario.expectedHero.subtitle,
                scenario.expectedHero.takeaway,
                scenario.expectedEvidence.bullets.joined(separator: " "),
                scenario.expectedLearnings.map(\.text).joined(separator: " "),
                scenario.expectedOpportunity.text
            ]
            .joined(separator: " ")
            .lowercased()

            for phrase in bannedPhrases {
                XCTAssertFalse(text.contains(phrase), "\(scenario.name) uses frequency-only activity language: \(phrase)")
            }

            XCTAssertTrue(
                requiredConcepts.contains { text.contains($0) },
                "\(scenario.name) should explain training meaning through volume, load, recovery response, or progression."
            )
        }
        #endif
    }

    func testFocusNextCanRouteToCoachForActionableGuidance() {
        let focus = InsightsFocusNext(
            label: "FOCUS NEXT",
            title: "Adjust today's plan",
            text: "The remaining plan exceeds what today can absorb.",
            action: "Use Coach to adjust the next session.",
            icon: "bolt.shield.fill",
            accent: WeekFitTheme.purple,
            domain: .activity,
            actionTitle: "Open Coach",
            actionDestination: .tab(.coach)
        )

        XCTAssertEqual(focus.actionDestination, .tab(.coach))
        XCTAssertEqual(focus.actionTitle, "Open Coach")
    }

    func testLearningAndOpportunityModelsDescribeInterpretationNotRawMetrics() {
        let learning = InsightsLearning(
            label: "STRONGEST PATTERN",
            title: "Recovery is absorbing frequent training",
            text: "Training is frequent, yet recovery remains stable enough to suggest the load is sustainable.",
            icon: "heart.fill",
            accent: WeekFitTheme.meal,
            domain: .recovery
        )
        let opportunity = InsightsOpportunity(
            label: "BIGGEST OPPORTUNITY",
            title: "Sleep is the next bottleneck to test",
            text: "Adding 30-45 minutes of sleep is more likely to improve recovery than adding another workout.",
            icon: "moon.zzz.fill",
            accent: WeekFitTheme.purple,
            domain: .sleep,
            actionDestination: .detail(.recovery)
        )

        XCTAssertEqual(learning.label, "STRONGEST PATTERN")
        XCTAssertTrue(learning.text.contains("suggest"))
        XCTAssertEqual(opportunity.actionDestination, .detail(.recovery))
    }

    func testDetailAndTabActionsHaveStableDistinctIDs() {
        XCTAssertNotEqual(
            InsightsActionDestination.detail(.nutrition).id,
            InsightsActionDestination.tab(.meals).id
        )
        XCTAssertEqual(
            InsightsActionDestination.detail(.recovery).id,
            "detail.recovery"
        )
    }
}
