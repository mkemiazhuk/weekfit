import Foundation

// MARK: - Public models

enum StressIndexLevel: String, Equatable, Hashable, CaseIterable {
    case low
    case moderate
    case elevated
    case high

    static func from(score: Int) -> StressIndexLevel {
        switch min(max(score, 0), 100) {
        case 0...24: return .low
        case 25...49: return .moderate
        case 50...74: return .elevated
        default: return .high
        }
    }
}

enum StressIndexConfidence: String, Equatable, Hashable {
    case high
    case medium
    case low
    case unavailable
}

enum StressIndexContributorKind: String, Equatable, Hashable {
    case hrv
    case restingHeartRate
    case sleep
    case trainingLoad
}

enum StressIndexContributorTone: String, Equatable, Hashable {
    case elevating
    case stabilizing
    case neutral
}

enum StressIndexImpact: String, Equatable, Hashable {
    case high
    case moderate
    case low

    static func from(strainScore: Int) -> StressIndexImpact {
        switch min(max(strainScore, 0), 100) {
        case 70...: return .high
        case 50..<70: return .moderate
        default: return .low
        }
    }
}

struct StressIndexContributor: Equatable, Hashable {
    let kind: StressIndexContributorKind
    /// Component strain on 0…100 (higher = more physiological strain).
    let strainScore: Int
    let weightUsed: Double
    let tone: StressIndexContributorTone
    /// Optional personal-baseline context for copy (ratios, deltas, minutes).
    let baselineNote: StressIndexBaselineNote?

    var impact: StressIndexImpact {
        StressIndexImpact.from(strainScore: strainScore)
    }
}

enum StressIndexBaselineNote: Equatable, Hashable {
    case hrvRatio(Double)
    case rhrDeltaBPM(Double)
    case sleepMinutes(Int)
    case training(RecoveryStrainLevel)
}

struct StressIndexResult: Equatable, Hashable {
    /// Precise score when confidence is medium or high. Never `0` for missing data.
    let score: Int?
    let level: StressIndexLevel?
    let confidence: StressIndexConfidence
    let contributors: [StressIndexContributor]
    let calculatedAt: Date

    /// Internal raw used for level when score is hidden (low confidence).
    let rawScore: Int?

    /// Actual personalized baseline sample days when available; never invented.
    let baselineSampleDays: Int?

    /// Signal kinds that contributed to this calculation.
    let usedSignalKinds: [StressIndexContributorKind]

    var displaysPreciseScore: Bool {
        score != nil && (confidence == .medium || confidence == .high)
    }

    static func unavailable(at date: Date = Date()) -> StressIndexResult {
        StressIndexResult(
            score: nil,
            level: nil,
            confidence: .unavailable,
            contributors: [],
            calculatedAt: date,
            rawScore: nil,
            baselineSampleDays: nil,
            usedSignalKinds: []
        )
    }
}

enum StressIndexRecoveryConflict: Equatable, Hashable {
    case highRecoveryElevatedStress
    case lowRecoveryLowStress
    case lowRecoveryHighStress
    case highRecoveryLowStress
    case none
}

enum StressIndexEngine {

    private static let hrvWeight = 0.35
    private static let rhrWeight = 0.25
    private static let sleepWeight = 0.20
    private static let trainingWeight = 0.20

    private static let sleepTargetMinutes = 480

    // MARK: - Public API

    static func calculate(
        _ input: RecoveryScoreInput,
        at calculatedAt: Date = Date()
    ) -> StressIndexResult {
        var components: [WeightedComponent] = []

        if let hrv = hrvStrain(from: input) {
            components.append(hrv)
        }
        if let rhr = rhrStrain(from: input) {
            components.append(rhr)
        }
        if let sleep = sleepStrain(from: input) {
            components.append(sleep)
        }
        if let training = trainingStrain(from: input) {
            components.append(training)
        }

        guard components.count >= 2 else {
            return .unavailable(at: calculatedAt)
        }

        let hasSleep = components.contains { $0.kind == .sleep }
        let hasPersonalizedPhysiology = components.contains {
            $0.kind == .hrv || $0.kind == .restingHeartRate
        }

        if !hasSleep && !hasPersonalizedPhysiology {
            return .unavailable(at: calculatedAt)
        }

        let totalWeight = components.reduce(0.0) { $0 + $1.baseWeight }
        guard totalWeight > 0 else {
            return .unavailable(at: calculatedAt)
        }

        let raw = components.reduce(0.0) { partial, component in
            partial + (Double(component.strainScore) * (component.baseWeight / totalWeight))
        }
        let clamped = Int(min(max(raw.rounded(), 0), 100))
        let level = StressIndexLevel.from(score: clamped)
        let confidence = resolveConfidence(
            components: components,
            hasSleep: hasSleep,
            hasPersonalizedHRV: components.contains { $0.kind == .hrv },
            hasPersonalizedRHR: components.contains { $0.kind == .restingHeartRate }
        )

        let contributors = components.map { component in
            StressIndexContributor(
                kind: component.kind,
                strainScore: component.strainScore,
                weightUsed: component.baseWeight / totalWeight,
                tone: tone(for: component.strainScore),
                baselineNote: component.baselineNote
            )
        }
        .sorted { lhs, rhs in
            if lhs.strainScore == rhs.strainScore {
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            return lhs.strainScore > rhs.strainScore
        }

        let showsScore = confidence == .medium || confidence == .high
        let usedKinds = contributors.map(\.kind)

        return StressIndexResult(
            score: showsScore ? clamped : nil,
            level: level,
            confidence: confidence,
            contributors: contributors,
            calculatedAt: calculatedAt,
            rawScore: clamped,
            baselineSampleDays: baselineSampleDays(from: input),
            usedSignalKinds: usedKinds
        )
    }

    private static func baselineSampleDays(from input: RecoveryScoreInput) -> Int? {
        var samples: [Int] = []
        if input.baseline.hasPersonalizedHRV {
            samples.append(input.baseline.hrvSampleCount)
        }
        if input.baseline.hasPersonalizedRHR {
            samples.append(input.baseline.restingHeartRateSampleCount)
        }
        guard let days = samples.max(), days > 0 else { return nil }
        return days
    }

    static func recoveryConflict(
        recoveryScore: Int,
        stress: StressIndexResult
    ) -> StressIndexRecoveryConflict {
        guard
            stress.confidence != .unavailable,
            let level = stress.level,
            recoveryScore > 0
        else {
            return .none
        }

        let highRecovery = recoveryScore >= 75
        let lowRecovery = recoveryScore < 55
        let elevatedOrHighStress = level == .elevated || level == .high
        let lowStress = level == .low

        if highRecovery && elevatedOrHighStress {
            return .highRecoveryElevatedStress
        }
        if lowRecovery && lowStress {
            return .lowRecoveryLowStress
        }
        if lowRecovery && elevatedOrHighStress {
            return .lowRecoveryHighStress
        }
        if highRecovery && lowStress {
            return .highRecoveryLowStress
        }
        return .none
    }

    // MARK: - Components

    private struct WeightedComponent {
        let kind: StressIndexContributorKind
        let strainScore: Int
        let baseWeight: Double
        let baselineNote: StressIndexBaselineNote?
    }

    private static func hrvStrain(from input: RecoveryScoreInput) -> WeightedComponent? {
        guard
            let hrv = input.hrvSDNN, hrv > 0,
            input.baseline.hasPersonalizedHRV,
            let baseline = input.baseline.hrvMedian, baseline > 0
        else {
            return nil
        }

        let ratio = hrv / baseline
        let strain: Int
        switch ratio {
        case 1.05...:
            strain = 12
        case 1.00..<1.05:
            strain = 22
        case 0.95..<1.00:
            strain = 35
        case 0.85..<0.95:
            strain = 55
        case 0.75..<0.85:
            strain = 75
        default:
            strain = min(100, max(90, Int((92.0 + (0.75 - ratio) * 40.0).rounded())))
        }

        return WeightedComponent(
            kind: .hrv,
            strainScore: strain,
            baseWeight: hrvWeight,
            baselineNote: .hrvRatio(ratio)
        )
    }

    private static func rhrStrain(from input: RecoveryScoreInput) -> WeightedComponent? {
        guard
            let rhr = input.restingHeartRate, rhr > 0,
            input.baseline.hasPersonalizedRHR,
            let baseline = input.baseline.restingHeartRateMedian
        else {
            return nil
        }

        let delta = rhr - baseline
        let strain: Int
        switch delta {
        case ...(-2):
            strain = 15
        case -2..<1:
            strain = 25
        case 1..<4:
            strain = 42
        case 4..<8:
            strain = 68
        default:
            strain = min(100, max(85, Int((88.0 + (delta - 8) * 2.0).rounded())))
        }

        return WeightedComponent(
            kind: .restingHeartRate,
            strainScore: strain,
            baseWeight: rhrWeight,
            baselineNote: .rhrDeltaBPM(delta)
        )
    }

    private static func sleepStrain(from input: RecoveryScoreInput) -> WeightedComponent? {
        guard input.sleepMinutes > 0 else { return nil }

        let minutes = input.sleepMinutes
        var strain: Int
        switch minutes {
        case sleepTargetMinutes...:
            strain = 12
        case 420..<sleepTargetMinutes:
            strain = 32
        case 360..<420:
            strain = 55
        case 300..<360:
            strain = 75
        default:
            strain = 92
        }

        if input.timeInBedMinutes > 0 {
            let efficiency = Double(input.sleepMinutes) / Double(input.timeInBedMinutes)
            if efficiency < 0.85 {
                strain = min(100, strain + 10)
            } else if input.awakeningsCount >= 5 {
                strain = min(100, strain + 6)
            }
        } else if input.awakeningsCount >= 5 {
            strain = min(100, strain + 6)
        }

        return WeightedComponent(
            kind: .sleep,
            strainScore: strain,
            baseWeight: sleepWeight,
            baselineNote: .sleepMinutes(minutes)
        )
    }

    private static func trainingStrain(from input: RecoveryScoreInput) -> WeightedComponent? {
        guard let load = input.priorDayLoad else { return nil }

        let strain: Int
        switch load.strainLevel {
        case .light:
            strain = 15
        case .moderate:
            strain = 50
        case .heavy:
            strain = 80
        }

        return WeightedComponent(
            kind: .trainingLoad,
            strainScore: strain,
            baseWeight: trainingWeight,
            baselineNote: .training(load.strainLevel)
        )
    }

    private static func resolveConfidence(
        components: [WeightedComponent],
        hasSleep: Bool,
        hasPersonalizedHRV: Bool,
        hasPersonalizedRHR: Bool
    ) -> StressIndexConfidence {
        let count = components.count

        if hasSleep && hasPersonalizedHRV && hasPersonalizedRHR {
            return .high
        }

        if count >= 3 || (hasSleep && (hasPersonalizedHRV || hasPersonalizedRHR)) {
            return .medium
        }

        return .low
    }

    private static func tone(for strainScore: Int) -> StressIndexContributorTone {
        switch strainScore {
        case 0..<30:
            return .stabilizing
        case 30..<50:
            return .neutral
        default:
            return .elevating
        }
    }
}

// MARK: - Localized presentation

enum StressIndexCopy {

    static func levelTitle(_ level: StressIndexLevel) -> String {
        switch level {
        case .low:
            return WeekFitLocalizedString("recovery.stressIndex.level.low")
        case .moderate:
            return WeekFitLocalizedString("recovery.stressIndex.level.moderate")
        case .elevated:
            return WeekFitLocalizedString("recovery.stressIndex.level.elevated")
        case .high:
            return WeekFitLocalizedString("recovery.stressIndex.level.high")
        }
    }

    static func confidenceTitle(_ confidence: StressIndexConfidence) -> String {
        switch confidence {
        case .high:
            return WeekFitLocalizedString("recovery.stressIndex.confidence.label.high")
        case .medium:
            return WeekFitLocalizedString("recovery.stressIndex.confidence.label.medium")
        case .low:
            return WeekFitLocalizedString("recovery.stressIndex.confidence.label.low")
        case .unavailable:
            return WeekFitLocalizedString("recovery.stressIndex.confidence.label.unavailable")
        }
    }

    static func impactTitle(_ impact: StressIndexImpact) -> String {
        switch impact {
        case .high:
            return WeekFitLocalizedString("recovery.stressIndex.impact.high")
        case .moderate:
            return WeekFitLocalizedString("recovery.stressIndex.impact.moderate")
        case .low:
            return WeekFitLocalizedString("recovery.stressIndex.impact.low")
        }
    }

    static func compactSummary(for result: StressIndexResult) -> String {
        switch result.confidence {
        case .unavailable:
            return WeekFitLocalizedString("recovery.stressIndex.empty.supporting")
        case .low:
            return WeekFitLocalizedString("recovery.stressIndex.confidence.low.summary")
        case .medium, .high:
            return summarySentence(for: result)
        }
    }

    /// Direction-aware hero explanation. Never says HRV is “elevated” when HRV is low.
    static func summarySentence(for result: StressIndexResult) -> String {
        let top = Array(result.contributors.prefix(2))
        guard !top.isEmpty else {
            return WeekFitLocalizedString("recovery.stressIndex.summary.generic")
        }

        if top.count == 1 {
            let clause = directionClause(for: top[0], capitalize: true)
            if top[0].tone == .elevating {
                return String(
                    format: WeekFitLocalizedString("recovery.stressIndex.summary.oneElevatingFormat"),
                    clause
                )
            }
            return clause
        }

        let first = top[0]
        let second = top[1]
        let firstClause = directionClause(for: first, capitalize: true)
        let secondClause = directionClause(for: second, capitalize: false)

        if first.tone == .elevating && second.tone == .elevating {
            return String(
                format: WeekFitLocalizedString("recovery.stressIndex.summary.twoElevatingFormat"),
                firstClause,
                secondClause
            )
        }

        if first.tone == .elevating && second.tone != .elevating {
            return String(
                format: WeekFitLocalizedString("recovery.stressIndex.summary.elevatingWhileStableFormat"),
                firstClause,
                secondClause
            )
        }

        if first.tone != .elevating && second.tone == .elevating {
            return String(
                format: WeekFitLocalizedString("recovery.stressIndex.summary.elevatingWhileStableFormat"),
                directionClause(for: second, capitalize: true),
                directionClause(for: first, capitalize: false)
            )
        }

        return WeekFitLocalizedString("recovery.stressIndex.summary.signalsStable")
    }

    /// Full-sentence direction clause for use in summaries (capitalized start for first clause).
    static func directionClause(for contributor: StressIndexContributor, capitalize: Bool = true) -> String {
        let key: String
        switch (contributor.kind, contributor.tone) {
        case (.hrv, .elevating):
            key = "recovery.stressIndex.clause.hrv.below"
        case (.hrv, .stabilizing), (.hrv, .neutral):
            key = "recovery.stressIndex.clause.hrv.stable"
        case (.restingHeartRate, .elevating):
            key = "recovery.stressIndex.clause.rhr.above"
        case (.restingHeartRate, .stabilizing), (.restingHeartRate, .neutral):
            key = "recovery.stressIndex.clause.rhr.stable"
        case (.sleep, .elevating):
            key = "recovery.stressIndex.clause.sleep.short"
        case (.sleep, .stabilizing), (.sleep, .neutral):
            key = "recovery.stressIndex.clause.sleep.stable"
        case (.trainingLoad, .elevating):
            key = "recovery.stressIndex.clause.training.heavy"
        case (.trainingLoad, .stabilizing), (.trainingLoad, .neutral):
            key = "recovery.stressIndex.clause.training.light"
        }

        let text = WeekFitLocalizedString(key)
        guard capitalize, let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    static func contributorHeadline(for contributor: StressIndexContributor) -> String {
        switch (contributor.kind, contributor.tone) {
        case (.hrv, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.row.hrv.below")
        case (.hrv, .stabilizing), (.hrv, .neutral):
            return WeekFitLocalizedString("recovery.stressIndex.row.hrv.stable")
        case (.restingHeartRate, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.row.rhr.above")
        case (.restingHeartRate, .stabilizing), (.restingHeartRate, .neutral):
            return WeekFitLocalizedString("recovery.stressIndex.row.rhr.stable")
        case (.sleep, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.row.sleep.short")
        case (.sleep, .stabilizing), (.sleep, .neutral):
            return WeekFitLocalizedString("recovery.stressIndex.row.sleep.stable")
        case (.trainingLoad, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.row.training.heavy")
        case (.trainingLoad, .stabilizing), (.trainingLoad, .neutral):
            return WeekFitLocalizedString("recovery.stressIndex.row.training.light")
        }
    }

    static func contributorDetail(for contributor: StressIndexContributor) -> String {
        switch (contributor.kind, contributor.tone) {
        case (.hrv, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.rowDetail.hrv.below")
        case (.hrv, .stabilizing), (.hrv, .neutral):
            return WeekFitLocalizedString("recovery.stressIndex.rowDetail.hrv.stable")
        case (.restingHeartRate, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.rowDetail.rhr.above")
        case (.restingHeartRate, .stabilizing), (.restingHeartRate, .neutral):
            return WeekFitLocalizedString("recovery.stressIndex.rowDetail.rhr.stable")
        case (.sleep, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.rowDetail.sleep.short")
        case (.sleep, .stabilizing), (.sleep, .neutral):
            return WeekFitLocalizedString("recovery.stressIndex.rowDetail.sleep.stable")
        case (.trainingLoad, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.rowDetail.training.heavy")
        case (.trainingLoad, .stabilizing), (.trainingLoad, .neutral):
            return WeekFitLocalizedString("recovery.stressIndex.rowDetail.training.light")
        }
    }

    static func contributorAccessibilityLabel(for contributor: StressIndexContributor) -> String {
        let impactPhrase: String
        switch contributor.tone {
        case .elevating:
            impactPhrase = WeekFitLocalizedString("recovery.stressIndex.a11y.increasedStress")
        case .stabilizing:
            impactPhrase = WeekFitLocalizedString("recovery.stressIndex.a11y.stabilizingStress")
        case .neutral:
            impactPhrase = WeekFitLocalizedString("recovery.stressIndex.a11y.neutralStress")
        }
        return "\(contributorHeadline(for: contributor)). \(impactPhrase)"
    }

    static func iconAccessibilityLabel(for tone: StressIndexContributorTone) -> String {
        switch tone {
        case .elevating:
            return WeekFitLocalizedString("recovery.stressIndex.a11y.icon.elevating")
        case .stabilizing:
            return WeekFitLocalizedString("recovery.stressIndex.a11y.icon.stabilizing")
        case .neutral:
            return WeekFitLocalizedString("recovery.stressIndex.a11y.icon.neutral")
        }
    }

    static func confidenceExplanation(
        _ confidence: StressIndexConfidence,
        baselineSampleDays: Int?
    ) -> String {
        switch confidence {
        case .high:
            if let days = baselineSampleDays, days > 0 {
                return String(
                    format: WeekFitLocalizedString("recovery.stressIndex.confidence.high.daysFormat"),
                    days
                )
            }
            return WeekFitLocalizedString("recovery.stressIndex.confidence.high")
        case .medium:
            return WeekFitLocalizedString("recovery.stressIndex.confidence.medium")
        case .low:
            return WeekFitLocalizedString("recovery.stressIndex.confidence.low")
        case .unavailable:
            return WeekFitLocalizedString("recovery.stressIndex.empty.supporting")
        }
    }

    static func meaningBody(for result: StressIndexResult, recoveryScore: Int) -> String {
        if let conflict = conflictExplanation(
            StressIndexEngine.recoveryConflict(recoveryScore: recoveryScore, stress: result)
        ) {
            return conflict
        }

        guard let level = result.level else {
            return WeekFitLocalizedString("recovery.stressIndex.meaning.unavailable")
        }

        switch level {
        case .low:
            return WeekFitLocalizedString("recovery.stressIndex.meaning.low")
        case .moderate:
            return WeekFitLocalizedString("recovery.stressIndex.meaning.moderate")
        case .elevated:
            return WeekFitLocalizedString("recovery.stressIndex.meaning.elevated")
        case .high:
            return WeekFitLocalizedString("recovery.stressIndex.meaning.high")
        }
    }

    static func conflictExplanation(_ conflict: StressIndexRecoveryConflict) -> String? {
        switch conflict {
        case .highRecoveryElevatedStress:
            return WeekFitLocalizedString("recovery.stressIndex.conflict.highRecoveryElevatedStress")
        case .lowRecoveryLowStress:
            return WeekFitLocalizedString("recovery.stressIndex.conflict.lowRecoveryLowStress")
        case .lowRecoveryHighStress:
            return WeekFitLocalizedString("recovery.stressIndex.conflict.lowRecoveryHighStress")
        case .highRecoveryLowStress:
            return WeekFitLocalizedString("recovery.stressIndex.conflict.highRecoveryLowStress")
        case .none:
            return nil
        }
    }

    static func calculationBody(usedKinds: [StressIndexContributorKind]) -> String {
        let labels = usedKinds.map(calculationSignalLabel)
        let signals: String
        if labels.isEmpty {
            signals = WeekFitLocalizedString("recovery.stressIndex.calculation.signals.default")
        } else if labels.count == 1 {
            signals = labels[0]
        } else if labels.count == 2 {
            signals = String(
                format: WeekFitLocalizedString("recovery.stressIndex.calculation.signals.twoFormat"),
                labels[0],
                labels[1]
            )
        } else {
            let head = labels.dropLast().joined(separator: ", ")
            signals = String(
                format: WeekFitLocalizedString("recovery.stressIndex.calculation.signals.listFormat"),
                head,
                labels.last ?? ""
            )
        }

        return String(
            format: WeekFitLocalizedString("recovery.stressIndex.calculation.bodyFormat"),
            signals
        )
    }

    static func accessibilityLabel(for result: StressIndexResult) -> String {
        let title = WeekFitLocalizedString("recovery.stressIndex.title")

        switch result.confidence {
        case .unavailable:
            return "\(title). \(WeekFitLocalizedString("recovery.stressIndex.empty.title"))"
        case .low:
            let level = result.level.map(levelTitle) ?? ""
            return "\(title), \(level)."
        case .medium, .high:
            let score = result.score.map(String.init) ?? ""
            let level = result.level.map { levelTitle($0).lowercased() } ?? ""
            return "\(title) \(score), \(level)."
        }
    }

    /// Short analytical line for the compact Recovery card — never a paragraph.
    static func compactInterpretation(for result: StressIndexResult) -> String {
        switch result.confidence {
        case .unavailable:
            return WeekFitLocalizedString("recovery.stressIndex.empty.supporting")
        case .low:
            return WeekFitLocalizedString("recovery.stressIndex.interpretation.lowConfidence")
        case .medium, .high:
            break
        }

        guard let level = result.level else {
            return WeekFitLocalizedString("recovery.stressIndex.interpretation.generic")
        }

        switch level {
        case .low:
            return WeekFitLocalizedString("recovery.stressIndex.interpretation.low")
        case .moderate:
            return WeekFitLocalizedString("recovery.stressIndex.interpretation.moderate")
        case .elevated:
            return WeekFitLocalizedString("recovery.stressIndex.interpretation.elevated")
        case .high:
            return WeekFitLocalizedString("recovery.stressIndex.interpretation.high")
        }
    }

    /// Compact contributor chips for the card footer (elevating first).
    static func compactContributorLabels(
        for result: StressIndexResult,
        bedtimeDeviationMinutes: Int? = nil
    ) -> [String] {
        let preferred = result.contributors.filter { $0.tone == .elevating }
        let source = preferred.isEmpty ? Array(result.contributors.prefix(2)) : Array(preferred.prefix(2))
        return source.map {
            compactContributorLabel(for: $0, bedtimeDeviationMinutes: bedtimeDeviationMinutes)
        }
    }

    static func compactContributorLabel(
        for contributor: StressIndexContributor,
        bedtimeDeviationMinutes: Int? = nil
    ) -> String {
        switch (contributor.kind, contributor.tone) {
        case (.hrv, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.chip.hrv.below")
        case (.hrv, _):
            return WeekFitLocalizedString("recovery.stressIndex.chip.hrv.stable")
        case (.restingHeartRate, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.chip.rhr.above")
        case (.restingHeartRate, _):
            return WeekFitLocalizedString("recovery.stressIndex.chip.rhr.stable")
        case (.sleep, .elevating):
            if let deviation = bedtimeDeviationMinutes, deviation >= 45 {
                return WeekFitLocalizedString("recovery.stressIndex.chip.sleep.late")
            }
            return WeekFitLocalizedString("recovery.stressIndex.chip.sleep.short")
        case (.sleep, _):
            return WeekFitLocalizedString("recovery.stressIndex.chip.sleep.stable")
        case (.trainingLoad, .elevating):
            return WeekFitLocalizedString("recovery.stressIndex.chip.training.heavy")
        case (.trainingLoad, _):
            return WeekFitLocalizedString("recovery.stressIndex.chip.training.light")
        }
    }

    private static func calculationSignalLabel(_ kind: StressIndexContributorKind) -> String {
        switch kind {
        case .hrv:
            return WeekFitLocalizedString("recovery.stressIndex.short.hrv")
        case .restingHeartRate:
            return WeekFitLocalizedString("recovery.stressIndex.short.rhr")
        case .sleep:
            return WeekFitLocalizedString("recovery.stressIndex.short.sleep")
        case .trainingLoad:
            return WeekFitLocalizedString("recovery.stressIndex.short.training")
        }
    }
}
