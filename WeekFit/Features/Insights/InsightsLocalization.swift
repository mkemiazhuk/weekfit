import Foundation

enum InsightsLocalization {
    static func text(_ key: String) -> String { WeekFitLocalizedString(key) }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: WeekFitLocalizedString(key), locale: WeekFitCurrentLocale(), arguments: args)
    }

    enum Section {
        static var whyThisStory: String { text("insights.section.whyThisStory") }
        static var whyThisScore: String { text("insights.section.whyThisScore") }
        static var trend: String { text("insights.section.trend") }
        static var driver: String { text("insights.section.driver") }
        static var action: String { text("insights.section.action") }
        static var nextFocus: String { text("insights.section.nextFocus") }
        static var dataCoverage: String { text("insights.section.dataCoverage") }
        static var recovery: String { text("insights.section.recovery") }
        static var sleep: String { text("insights.section.sleep") }
        static var activity: String { text("insights.section.activity") }
        static var nutrition: String { text("insights.section.nutrition") }
        static var meals: String { text("insights.section.meals") }
        static var water: String { text("insights.section.water") }
        static var training: String { text("insights.section.training") }
        static var trustMeter: String { text("insights.section.trustMeter") }
        static var building: String { text("insights.section.building") }
        static var secondarySignal: String { text("insights.section.secondarySignal") }
        static var goal: String { text("insights.section.goal") }
        static var expectedOutcome: String { text("insights.section.expectedOutcome") }
        static var strongestPattern: String { text("insights.section.strongestPattern") }
        static var emergingTrend: String { text("insights.section.emergingTrend") }
        static var weakestSignal: String { text("insights.section.weakestSignal") }
        static var whatWeLearned: String { text("insights.section.whatWeLearned") }
        static var adjacentSignal: String { text("insights.section.adjacentSignal") }
        static var recoveryClue: String { text("insights.section.recoveryClue") }
        static var biggestOpportunity: String { text("insights.section.biggestOpportunity") }
        static var mostLikelyNextImprovement: String { text("insights.section.mostLikelyNextImprovement") }
        static var recoveryResponse: String { text("insights.section.recoveryResponse") }
        static var trainingAndRecovery: String { text("insights.section.trainingAndRecovery") }
        static var nutritionInsight: String { text("insights.section.nutritionInsight") }
        static var hydrationInsight: String { text("insights.section.hydrationInsight") }
        static var weeklyReflection: String { text("insights.section.weeklyReflection") }
    }

    enum Confidence {
        static var high: String { text("insights.story.confidence.high") }
        static var medium: String { text("insights.story.confidence.medium") }
        static var low: String { text("insights.story.confidence.low") }

        static func label(for value: Double) -> String {
            switch value {
            case 0.78...: return high
            case 0.55..<0.78: return medium
            default: return low
            }
        }

        static func shortLabel(for value: Double) -> String {
            switch value {
            case 0.78...: return text("insights.view.confidence.highShort")
            case 0.55..<0.78: return text("insights.view.confidence.mediumShort")
            default: return Section.building
            }
        }

        static func withPercent(value: Double) -> String {
            let percent = Int((min(max(value, 0), 1) * 100).rounded())
            let label = label(for: value)
            guard percent > 0 else { return label }
            return format("insights.view.confidence.withPercentFormat", label, percent)
        }
    }

    enum StoryType {
        static var change: String { text("insights.story.type.change") }
        static var risk: String { text("insights.story.type.risk") }
        static var opportunity: String { text("insights.story.type.opportunity") }
        static var anomaly: String { text("insights.story.type.anomaly") }
        static var plateau: String { text("insights.story.type.plateau") }
        static var maintenance: String { text("insights.story.type.maintenance") }
    }

    enum View {
        static var screenTitle: String { text("insights.view.screenTitle") }
        static var screenSubtitle: String { text("insights.view.screenSubtitle") }
        static var activityLoad: String { text("insights.view.activityLoad") }
        static var chart30dAgo: String { text("insights.view.chart.30dAgo") }
        static var chart15d: String { text("insights.view.chart.15d") }
        static var notEnoughDataYet: String { text("insights.view.notEnoughDataYet") }
        static var sleepScore: String { text("insights.view.hero.sleepScore") }
        static var recoveryScore: String { text("insights.view.hero.recoveryScore") }
        static var sleepDuration: String { text("insights.view.hero.sleepDuration") }
        static var trainingLoad: String { text("insights.view.hero.trainingLoad") }
        static var nutritionSignal: String { text("insights.view.hero.nutritionSignal") }
        static var hydrationSignal: String { text("insights.view.hero.hydrationSignal") }
        static var consistency: String { text("insights.view.hero.consistency") }
        static var patternReadiness: String { text("insights.view.hero.patternReadiness") }
        static var averageSuffix: String { text("insights.view.hero.averageSuffix") }
        static var scoreOutOf100Format: String { text("insights.view.hero.scoreOutOf100Format") }
        static var sleepTargetGapFormat: String { text("insights.view.hero.sleepTargetGapFormat") }
        static var aboveTargetFormat: String { text("insights.view.hero.aboveTargetFormat") }
        static var belowTargetFormat: String { text("insights.view.hero.belowTargetFormat") }
        static var trendNoChange: String { text("insights.view.trend.noChange") }
        static var trendBuildsWithData: String { text("insights.view.trend.buildsWithData") }
        static var trendImproving: String { text("insights.view.trend.improving") }
        static var trendDeclining: String { text("insights.view.trend.declining") }
        static var trendStable: String { text("insights.view.trend.stable") }
        static var driverSleepDuration: String { text("insights.view.driver.sleepDuration") }
        static var driverTrainingLoad: String { text("insights.view.driver.trainingLoad") }
        static var driverProteinConsistency: String { text("insights.view.driver.proteinConsistency") }
        static var driverRecoveryConsistency: String { text("insights.view.driver.recoveryConsistency") }
        static var driverHydration: String { text("insights.view.driver.hydration") }
        static var driverLoggingConsistency: String { text("insights.view.driver.loggingConsistency") }
        static var targetSleep7h: String { text("insights.view.target.sleep7h") }
        static var targetProtein6of7: String { text("insights.view.target.protein6of7") }
        static var targetStableWeeklyLoad: String { text("insights.view.target.stableWeeklyLoad") }
        static var targetRecovery72: String { text("insights.view.target.recovery72") }
        static var targetConsistentIntake: String { text("insights.view.target.consistentIntake") }
        static var targetCompleteLogs: String { text("insights.view.target.completeLogs") }
        static var expectedOutcomeFallback: String { text("insights.view.expectedOutcomeFallback") }
        static var driverExplanationSleepDecline: String { text("insights.view.driverExplanation.sleepDecline") }
        static var driverExplanationSleepSupport: String { text("insights.view.driverExplanation.sleepSupport") }
        static var driverExplanationActivityDecline: String { text("insights.view.driverExplanation.activityDecline") }
        static var driverExplanationActivitySupport: String { text("insights.view.driverExplanation.activitySupport") }
        static var driverExplanationNutrition: String { text("insights.view.driverExplanation.nutrition") }
        static var driverExplanationRecovery: String { text("insights.view.driverExplanation.recovery") }
        static var driverExplanationHydration: String { text("insights.view.driverExplanation.hydration") }
        static var driverExplanationMissingData: String { text("insights.view.driverExplanation.missingData") }
        static var graphComparison: String { text("insights.view.graph.comparison") }
        static var graphDistribution: String { text("insights.view.graph.distribution") }
        static var graphPairedSignals: String { text("insights.view.graph.pairedSignals") }
        static var graphConsistency: String { text("insights.view.graph.consistency") }
        static var graphWeeklyPattern: String { text("insights.view.graph.weeklyPattern") }
        static var graphSignalStrength: String { text("insights.view.graph.signalStrength") }
        static var graphContributors: String { text("insights.view.graph.contributors") }
        static var graphTrendChange: String { text("insights.view.graph.trendChange") }
        static var graphMonthlySleep: String { text("insights.view.graph.monthlySleep") }
        static var graphMonthlyRecovery: String { text("insights.view.graph.monthlyRecovery") }
        static var graphMonthlyTraining: String { text("insights.view.graph.monthlyTraining") }
        static var graphMonthlyNutrition: String { text("insights.view.graph.monthlyNutrition") }
        static var graphMonthlyHydration: String { text("insights.view.graph.monthlyHydration") }
        static var graphPatternBuilding: String { text("insights.view.graph.patternBuilding") }
        static var graphCaptionDistribution: String { text("insights.view.graphCaption.distribution") }
        static var graphCaptionCorrelationFormat: String { text("insights.view.graphCaption.correlationFormat") }
        static var graphCaptionConsistencyFormat: String { text("insights.view.graphCaption.consistencyFormat") }
        static var graphCaptionWeeklyPattern: String { text("insights.view.graphCaption.weeklyPattern") }
        static var graphCaptionContributors: String { text("insights.view.graphCaption.contributors") }

        static func chartZones(
            for domain: InsightsDomain
        ) -> (upper: String, middle: String, lower: String, upperBoundary: Double, middleBoundary: Double) {
            switch domain {
            case .activity:
                return (
                    text("insights.view.chart.highLoad"),
                    text("insights.domain.chartSustainableLoad"),
                    text("insights.view.chart.lowLoad"),
                    0.70, 0.30
                )
            case .recovery:
                return (
                    text("insights.view.chart.strongRecovery"),
                    text("insights.domain.chartTargetRange"),
                    text("insights.view.chart.lowRecovery"),
                    0.75, 0.40
                )
            case .nutrition:
                return (
                    text("insights.view.chart.proteinTarget"),
                    text("insights.view.chart.consistentIntake"),
                    text("insights.view.chart.belowTarget"),
                    0.80, 0.50
                )
            default:
                return (
                    text("insights.view.chart.high"),
                    text("insights.domain.chartTargetRange"),
                    text("insights.view.chart.low"),
                    0.75, 0.40
                )
            }
        }

        static func refinedActionTitle(for destination: InsightsActionDestination?, fallback: String) -> String {
            switch destination {
            case .detail(.recovery): return text("insights.action.viewRecoveryAnalysis")
            case .detail(.activity): return text("insights.action.reviewTrainingTrends")
            case .detail(.nutrition): return text("insights.action.exploreNutritionDetails")
            case .tab(.coach): return text("insights.action.openCoach")
            case .tab(.today): return text("insights.action.logToday")
            case .tab(.meals): return text("insights.action.openNutrition")
            case .tab(.calendar): return text("insights.action.openPlan")
            case nil: return fallback
            }
        }

        static func actionTitle(for destination: InsightsActionDestination) -> String {
            switch destination {
            case .detail(.activity): return text("insights.action.openActivity")
            case .detail(.nutrition): return text("insights.action.openNutrition")
            case .detail(.recovery): return text("insights.action.openRecovery")
            case .tab(.coach): return text("insights.action.openCoach")
            case .tab(.today): return text("insights.action.logToday")
            case .tab(.meals): return text("insights.action.openNutrition")
            case .tab(.calendar): return text("insights.action.openPlan")
            }
        }
    }

    enum VM {
        static func workloadSignificanceText(for category: String) -> String {
            switch category {
            case "Recovery Week": return text("insights.vm.workload.recoveryWeek")
            case "Light Week": return text("insights.vm.workload.lightWeek")
            case "Normal Week": return text("insights.vm.workload.normalWeek")
            case "Productive Week": return text("insights.vm.workload.productiveWeek")
            case "Heavy Week": return text("insights.vm.workload.heavyWeek")
            default: return text("insights.vm.workload.veryHighLoad")
            }
        }
    }

    static func storyTypeLabel(_ type: InsightsStoryType) -> String {
        switch type {
        case .changeStory: return StoryType.change
        case .riskStory: return StoryType.risk
        case .opportunityStory: return StoryType.opportunity
        case .anomalyStory: return StoryType.anomaly
        case .plateauReversalStory: return StoryType.plateau
        case .maintenanceStory: return StoryType.maintenance
        }
    }

    static func localizedWorkloadCategory(_ category: String) -> String {
        switch category {
        case "Recovery Week": return text("insights.signal.load.recoveryWeek")
        case "High Load": return text("insights.signal.load.high")
        case "Solid Load": return text("insights.signal.load.solid")
        case "Base Load": return text("insights.signal.load.base")
        default: return category
        }
    }

    static func statusText(for score: Int) -> String {
        if score >= 85 { return text("insights.status.excellent") }
        if score >= 72 { return text("insights.status.strong") }
        if score >= 60 { return text("insights.status.fair") }
        return text("insights.status.needsAttention")
    }
}
