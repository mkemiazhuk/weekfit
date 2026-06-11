import SwiftUI

struct InsightsSnapshot {
    let avatarInitials: String
    let weekDays: [String]
    let hero: InsightsHeroInsight
    let evidence: InsightsEvidence
    let whyItems: [InsightsWhyItem]
    let nextActions: [InsightsNextAction]
    let supportCards: [InsightSupportCard]
    let learnings: [InsightsLearning]
    let opportunity: InsightsOpportunity?
    let weeklyScores: [InsightsMiniScore]
    let trends: [InsightsTrendCard]
    let hydrationImpact: InsightsCorrelationCard
    let weeklyReflection: InsightsReflection
    let focusNext: InsightsFocusNext
    let dataQuality: InsightsDataQuality

    init(
        avatarInitials: String,
        weekDays: [String],
        hero: InsightsHeroInsight,
        evidence: InsightsEvidence = .fallback,
        whyItems: [InsightsWhyItem] = [],
        nextActions: [InsightsNextAction] = [],
        supportCards: [InsightSupportCard] = [],
        learnings: [InsightsLearning] = [],
        opportunity: InsightsOpportunity? = nil,
        weeklyScores: [InsightsMiniScore],
        trends: [InsightsTrendCard],
        hydrationImpact: InsightsCorrelationCard,
        weeklyReflection: InsightsReflection,
        focusNext: InsightsFocusNext,
        dataQuality: InsightsDataQuality
    ) {
        self.avatarInitials = avatarInitials
        self.weekDays = weekDays
        self.hero = hero
        self.evidence = evidence
        self.whyItems = whyItems
        self.nextActions = nextActions
        self.supportCards = supportCards
        self.learnings = learnings
        self.opportunity = opportunity
        self.weeklyScores = weeklyScores
        self.trends = trends
        self.hydrationImpact = hydrationImpact
        self.weeklyReflection = weeklyReflection
        self.focusNext = focusNext
        self.dataQuality = dataQuality
    }

    static let fallback = InsightsSnapshot(
        avatarInitials: "WF",
        weekDays: ["M", "T", "W", "T", "F", "S", "S"],
        hero: InsightsHeroInsight(
            label: "BUILDING PATTERNS",
            title: "Building your patterns",
            subtitle: "Log sleep, meals, drinks and activities for a few more days to unlock trends.",
            takeaway: "Start with one consistent week.",
            icon: "brain.head.profile",
            accent: WeekFitTheme.meal,
            graphValues: [0.32, 0.42, 0.38, 0.48, 0.45, 0.52, 0.50],
            badgeValue: "—",
            badgeLabel: "patterns",
            domain: .missingData
        ),
        evidence: InsightsEvidence.fallback,
        whyItems: [
            InsightsWhyItem(
                title: "Not enough recent context",
                value: "7 days",
                detail: "A consistent week gives Coach something useful to compare.",
                icon: "calendar",
                domain: .missingData
            ),
            InsightsWhyItem(
                title: "Core signals are still missing",
                value: "Sleep, food, training",
                detail: "The read gets better once those logs overlap.",
                icon: "sparkles",
                domain: .missingData
            )
        ],
        nextActions: [
            InsightsNextAction(
                title: "Log consistently for 7 days",
                detail: "Sleep, meals, drinks and training are enough to start.",
                icon: "checkmark.circle.fill",
                destination: .tab(.today)
            )
        ],
        supportCards: [
            InsightSupportCard(
                role: .opportunity,
                title: "Build the baseline first",
                text: "A reliable baseline will let Insights compare averages, direction and change instead of reporting raw logging counts.",
                icon: "target",
                accent: WeekFitTheme.meal,
                metrics: [
                    InsightTrendMetric(label: "Baseline", value: "Building", direction: .stable, detail: "Not enough overlap yet", benchmark: "Needs sleep, recovery, training and nutrition context")
                ]
            )
        ],
        learnings: [
            InsightsLearning(
                label: "WHAT WE LEARNED",
                title: "Patterns are still forming",
                text: "A few more consistent days will let Insights separate signal from noise.",
                icon: "sparkles",
                accent: WeekFitTheme.meal,
                domain: .missingData
            )
        ],
        opportunity: InsightsOpportunity(
            label: "BIGGEST OPPORTUNITY",
            title: "Build the baseline first",
            text: "Consistent sleep, recovery, training and nutrition logs are the fastest path to useful discoveries.",
            icon: "target",
            accent: WeekFitTheme.meal,
            domain: .missingData,
            actionDestination: .tab(.today)
        ),
        weeklyScores: [
            InsightsMiniScore(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "—", detail: "log recovery"),
            InsightsMiniScore(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "—", detail: "log sleep"),
            InsightsMiniScore(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Training", value: "—", detail: "build baseline"),
            InsightsMiniScore(icon: "fork.knife", iconColor: WeekFitTheme.blue, title: "Nutrition", value: "—", detail: "build baseline")
        ],
        trends: [
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Training pattern unavailable", subtitle: "Build enough activity history to compare workload against your baseline.", takeaway: "Start by creating a reliable workload trend.", icon: "figure.run", domain: .activity),
            InsightsTrendCard(accent: WeekFitTheme.meal, label: "NUTRITION PATTERN", title: "Nutrition insight unavailable", subtitle: "Build enough meal history to compare protein and recovery trends.", takeaway: "Protein consistency unlocks better recovery context.", icon: "fork.knife", domain: .nutrition)
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION INSIGHT",
            title: "Hydration insight unavailable",
            subtitle: "Build enough drink history to compare hydration with recovery.",
            rows: [
                InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: ["—", "—", "—"], color: WeekFitTheme.blue),
                InsightsCorrelationRow(icon: "heart.fill", title: "Recovery context", values: ["—", "—", "—"], color: WeekFitTheme.meal)
            ]
        ),
        weeklyReflection: InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "Building your patterns. Log sleep, meals, drinks and activities for a few more days to unlock trends.",
            domain: .missingData
        ),
        focusNext: InsightsFocusNext(
            label: "FOCUS NEXT",
            title: "Build the baseline first",
            text: "Insights becomes useful once sleep, recovery, food, drink and activity have enough recent history.",
            action: "Log the next 7 days consistently.",
            icon: "sparkles",
            accent: WeekFitTheme.meal,
            domain: .missingData
        ),
        dataQuality: InsightsDataQuality(
            recoveryDays: 0,
            sleepDays: 0,
            hydrationDays: 0,
            mealDays: 0,
            activityDays: 0,
            plannerDays: 0
        )
    )
}

enum InsightsDomain: Hashable {
    case recovery
    case sleep
    case nutrition
    case hydration
    case activity
    case consistency
    case missingData
}

enum InsightType: String, CaseIterable, Hashable {
    case sleep
    case training
    case recovery
    case nutrition
    case hydration
    case consistency
    case missingData
}

enum InsightTrendDirection: String, CaseIterable, Hashable {
    case increasing
    case decreasing
    case stable

    var symbol: String {
        switch self {
        case .increasing: return "↑"
        case .decreasing: return "↓"
        case .stable: return "→"
        }
    }

    var label: String {
        switch self {
        case .increasing: return "increasing"
        case .decreasing: return "decreasing"
        case .stable: return "stable"
        }
    }
}

struct InsightTrendMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let direction: InsightTrendDirection
    let detail: String
    let benchmark: String
}

enum InsightSupportRole: String, CaseIterable, Hashable {
    case strongestPattern
    case bottleneck
    case relationship
    case experiment
    case workload
    case adaptation
    case progression
    case risk
    case resilience
    case limitingFactor
    case recoveryDriver
    case opportunity
}

struct InsightSupportCard: Identifiable {
    let id = UUID()
    let role: InsightSupportRole
    let domain: InsightsDomain
    let title: String
    let text: String
    let icon: String
    let accent: Color
    let metrics: [InsightTrendMetric]

    init(
        role: InsightSupportRole,
        domain: InsightsDomain? = nil,
        title: String,
        text: String,
        icon: String,
        accent: Color,
        metrics: [InsightTrendMetric]
    ) {
        self.role = role
        self.domain = domain ?? Self.defaultDomain(for: role)
        self.title = title
        self.text = text
        self.icon = icon
        self.accent = accent
        self.metrics = metrics
    }

    private static func defaultDomain(for role: InsightSupportRole) -> InsightsDomain {
        switch role {
        case .strongestPattern, .bottleneck, .experiment:
            return .sleep
        case .relationship, .resilience, .limitingFactor, .recoveryDriver, .opportunity:
            return .recovery
        case .workload, .adaptation, .progression, .risk:
            return .activity
        }
    }
}

enum InsightsDetailDestination: Equatable, Identifiable {
    case activity
    case nutrition
    case recovery

    var id: String {
        switch self {
        case .activity: return "activity"
        case .nutrition: return "nutrition"
        case .recovery: return "recovery"
        }
    }
}

enum InsightsActionDestination: Equatable, Identifiable {
    case detail(InsightsDetailDestination)
    case tab(WeekFitTab)

    var id: String {
        switch self {
        case .detail(let destination):
            return "detail.\(destination.id)"
        case .tab(let tab):
            return "tab.\(tab)"
        }
    }
}

struct InsightsDataQuality {
    let recoveryDays: Int
    let sleepDays: Int
    let hydrationDays: Int
    let mealDays: Int
    let activityDays: Int
    let plannerDays: Int

    var hasAnySignal: Bool {
        [recoveryDays, sleepDays, hydrationDays, mealDays, activityDays, plannerDays].contains { $0 > 0 }
    }
}

struct InsightsEvidence {
    let label: String
    let confidenceLabel: String
    let confidenceValue: Double
    let sourceSummary: String
    let recencyText: String
    let bullets: [String]

    static let fallback = InsightsEvidence(
        label: "WHY THIS",
        confidenceLabel: "Building",
        confidenceValue: 0.35,
        sourceSummary: "Waiting for enough recent data",
        recencyText: "Updates as you log",
        bullets: [
            "Sleep, recovery, nutrition, hydration and activity become smarter with consistent logs.",
            "The first useful pattern usually appears after several recent days."
        ]
    )
}

struct InsightsWhyItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let icon: String
    let domain: InsightsDomain
}

struct InsightsNextAction: Identifiable {
    let id = UUID()
    let title: String
    let detail: String?
    let icon: String
    let destination: InsightsActionDestination?
}

struct InsightsLearning: Identifiable {
    let id = UUID()
    let label: String
    let title: String
    let text: String
    let icon: String
    let accent: Color
    let domain: InsightsDomain
}

struct InsightsOpportunity {
    let label: String
    let title: String
    let text: String
    let icon: String
    let accent: Color
    let domain: InsightsDomain
    let actionDestination: InsightsActionDestination?
}

struct InsightsCoachContext {
    let title: String
    let message: String
    let stateLabel: String
    let icon: String
    let accent: Color
    let confidence: Double
    let evidence: [String]
    let recommendation: String
    let actionTitle: String
    let domain: InsightsDomain
    let actionDestination: InsightsActionDestination
    let shouldLeadInsights: Bool
}

enum InsightVisualization {
    case trendLine(values: [Double], target: Double?, targetLabel: String?)
    case comparison(primaryLabel: String, primaryValue: String, secondaryLabel: String, secondaryValue: String, delta: String)
    case distribution(values: [Double], highlightIndex: Int?)
    case correlation(primary: [Double], secondary: [Double], primaryLabel: String, secondaryLabel: String)
    case consistency(values: [Bool], positiveLabel: String, negativeLabel: String)
    case weeklyPattern(values: [Double], labels: [String])
    case contributionBreakdown(segments: [InsightContribution])
    case relationshipGraph(primary: [Double], secondary: [Double], insightLabel: String)
    case trendChange(before: [Double], after: [Double], label: String)
    case signalStrength(strength: Double, label: String)
}

enum InsightVisualizationKind: String, CaseIterable, Equatable {
    case trendLine
    case comparison
    case distribution
    case correlation
    case consistency
    case weeklyPattern
    case contributionBreakdown
    case relationshipGraph
    case trendChange
    case signalStrength
}

extension InsightVisualization {
    var kind: InsightVisualizationKind {
        switch self {
        case .trendLine:
            return .trendLine
        case .comparison:
            return .comparison
        case .distribution:
            return .distribution
        case .correlation:
            return .correlation
        case .consistency:
            return .consistency
        case .weeklyPattern:
            return .weeklyPattern
        case .contributionBreakdown:
            return .contributionBreakdown
        case .relationshipGraph:
            return .relationshipGraph
        case .trendChange:
            return .trendChange
        case .signalStrength:
            return .signalStrength
        }
    }
}

struct InsightContribution: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct InsightsHeroInsight {
    let label: String
    let title: String
    let subtitle: String
    let takeaway: String
    let timeframe: String
    let icon: String
    let accent: Color
    let graphValues: [Double]
    let targetValue: Double?
    let targetLabel: String?
    let visualization: InsightVisualization
    let badgeValue: String
    let badgeLabel: String
    let domain: InsightsDomain
    let insightType: InsightType
    let actionDestination: InsightsActionDestination?

    init(
        label: String,
        title: String,
        subtitle: String,
        takeaway: String,
        timeframe: String = "Recent pattern",
        icon: String,
        accent: Color,
        graphValues: [Double],
        targetValue: Double? = nil,
        targetLabel: String? = nil,
        visualization: InsightVisualization? = nil,
        badgeValue: String,
        badgeLabel: String,
        domain: InsightsDomain,
        insightType: InsightType? = nil,
        actionDestination: InsightsActionDestination? = nil
    ) {
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.takeaway = takeaway
        self.timeframe = timeframe
        self.icon = icon
        self.accent = accent
        self.graphValues = graphValues
        self.targetValue = targetValue
        self.targetLabel = targetLabel
        self.visualization = visualization ?? .trendLine(
            values: graphValues,
            target: targetValue,
            targetLabel: targetLabel
        )
        self.badgeValue = badgeValue
        self.badgeLabel = badgeLabel
        self.domain = domain
        self.insightType = insightType ?? Self.defaultInsightType(for: domain)
        self.actionDestination = actionDestination
    }

    private static func defaultInsightType(for domain: InsightsDomain) -> InsightType {
        switch domain {
        case .sleep:
            return .sleep
        case .activity:
            return .training
        case .recovery:
            return .recovery
        case .nutrition:
            return .nutrition
        case .hydration:
            return .hydration
        case .consistency:
            return .consistency
        case .missingData:
            return .missingData
        }
    }
}

struct InsightsMiniScore: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let detail: String
    let destination: InsightsDetailDestination?

    init(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        detail: String,
        destination: InsightsDetailDestination? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.detail = detail
        self.destination = destination
    }
}

struct InsightsTrendCard: Identifiable {
    let id = UUID()
    let accent: Color
    let label: String
    let title: String
    let subtitle: String
    let takeaway: String
    let icon: String
    let domain: InsightsDomain
    let actionDestination: InsightsActionDestination?

    init(
        accent: Color,
        label: String,
        title: String,
        subtitle: String,
        takeaway: String,
        icon: String,
        domain: InsightsDomain,
        actionDestination: InsightsActionDestination? = nil
    ) {
        self.accent = accent
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.takeaway = takeaway
        self.icon = icon
        self.domain = domain
        self.actionDestination = actionDestination
    }
}

struct InsightsCorrelationCard {
    let label: String
    let title: String
    let subtitle: String
    let rows: [InsightsCorrelationRow]
    let domain: InsightsDomain
    let actionDestination: InsightsActionDestination?

    init(
        label: String,
        title: String,
        subtitle: String,
        rows: [InsightsCorrelationRow],
        domain: InsightsDomain = .hydration,
        actionDestination: InsightsActionDestination? = .detail(.nutrition)
    ) {
        self.label = label
        self.title = title
        self.subtitle = subtitle
        self.rows = rows
        self.domain = domain
        self.actionDestination = actionDestination
    }
}

struct InsightsCorrelationRow: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let values: [String]
    let color: Color
}

struct InsightsReflection {
    let label: String
    let text: String
    let domain: InsightsDomain
    let actionDestination: InsightsActionDestination?

    init(
        label: String,
        text: String,
        domain: InsightsDomain,
        actionDestination: InsightsActionDestination? = nil
    ) {
        self.label = label
        self.text = text
        self.domain = domain
        self.actionDestination = actionDestination
    }
}

struct InsightsFocusNext {
    let label: String
    let title: String
    let text: String
    let action: String
    let icon: String
    let accent: Color
    let domain: InsightsDomain
    let actionTitle: String
    let actionDestination: InsightsActionDestination?

    init(
        label: String,
        title: String,
        text: String,
        action: String,
        icon: String,
        accent: Color,
        domain: InsightsDomain,
        actionTitle: String = "Open next step",
        actionDestination: InsightsActionDestination? = nil
    ) {
        self.label = label
        self.title = title
        self.text = text
        self.action = action
        self.icon = icon
        self.accent = accent
        self.domain = domain
        self.actionTitle = actionTitle
        self.actionDestination = actionDestination
    }
}

enum InsightScenarioClass: String, CaseIterable, Hashable, Identifiable {
    case sleepOpportunity
    case recoveryTrend
    case trainingConsistency
    case overtrainingRisk
    case hydrationPattern
    case nutritionQuality
    case proteinDeficiency
    case weekendBehavior
    case trainingFrequency
    case hrvTrend
    case activeCalorieTrend
    case recoveryResilience
    case loadManagement
    case stressAccumulation
    case restDayEffectiveness
    case cardioFitness
    case behaviorChange
    case trendReversal
    case plateau
    case consistency
    case missingData

    var id: String { rawValue }
}

struct InsightScenario: Identifiable {
    let id: String
    let insightClass: InsightScenarioClass
    let name: String
    let triggerConditions: [String]
    let expectedHero: InsightsHeroInsight
    let expectedVisualizationType: InsightVisualizationKind
    let expectedEvidence: InsightsEvidence
    let expectedSupportCards: [InsightSupportCard]
    let expectedLearnings: [InsightsLearning]
    let expectedOpportunity: InsightsOpportunity
    let dataQuality: InsightsDataQuality

    var snapshot: InsightsSnapshot {
        InsightsSnapshot(
            avatarInitials: "WF",
            weekDays: ["M", "T", "W", "T", "F", "S", "S"],
            hero: expectedHero,
            evidence: expectedEvidence,
            supportCards: expectedSupportCards,
            learnings: expectedLearnings,
            opportunity: expectedOpportunity,
            weeklyScores: [],
            trends: [],
            hydrationImpact: InsightsCorrelationCard(label: "", title: "", subtitle: "", rows: [], domain: expectedHero.domain, actionDestination: nil),
            weeklyReflection: InsightsReflection(label: "", text: "", domain: expectedHero.domain),
            focusNext: InsightsFocusNext(label: "", title: "", text: "", action: "", icon: expectedHero.icon, accent: expectedHero.accent, domain: expectedHero.domain),
            dataQuality: dataQuality
        )
    }
}
