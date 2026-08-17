import Foundation

/// Precomputed Home Screen widget payload. Built by the main app only.
public struct WeekFitWidgetSnapshot: Codable, Equatable, Sendable {
    public enum DayMode: String, Codable, Sendable {
        case goodToGo
        case takeItEasy
        case recoveryFocus
        case maintain
        case empty
    }

    public enum NextActionKind: String, Codable, Sendable {
        case walk
        case strength
        case recovery
        case sauna
        case meal
        case hydration
        case rest
        case none
    }

    /// Whether the highlighted plan item is still upcoming or already underway.
    public enum NextActionPhase: String, Codable, Sendable {
        case none
        case upcoming
        case inProgress
        case due
    }

    public var dateKey: String
    public var activityProgress: Double
    public var activityCalories: Int
    public var activityGoal: Int
    public var hasActivitySignal: Bool

    public var nutritionProgress: Double
    public var consumedCalories: Int
    public var remainingCalories: Int
    public var hasNutritionSignal: Bool

    public var recoveryScore: Int?
    public var sleepHours: Double?
    public var recoveryLabel: String?
    public var hasRecoverySignal: Bool

    public var dayMode: DayMode
    /// Compact day-state eyebrow for Small (e.g. "Good to go", "Before sauna").
    /// Empty means derive from `dayMode`.
    public var dayStateLabel: String
    /// WeekFit interpretation / hero line.
    public var dayGuidance: String
    /// Optional short supporting line.
    public var dayGuidanceDetail: String

    public var nextActionTitle: String
    public var nextActionSubtitle: String
    public var nextActionTime: String?
    public var nextActionKind: NextActionKind
    public var nextActionPhase: NextActionPhase

    public var completedItems: Int
    public var totalItems: Int

    public var updatedAt: Date
    public var schemaVersion: Int

    public static let currentSchemaVersion = 3

    public init(
        dateKey: String,
        activityProgress: Double,
        activityCalories: Int,
        activityGoal: Int,
        hasActivitySignal: Bool,
        nutritionProgress: Double,
        consumedCalories: Int,
        remainingCalories: Int,
        hasNutritionSignal: Bool,
        recoveryScore: Int?,
        sleepHours: Double?,
        recoveryLabel: String?,
        hasRecoverySignal: Bool,
        dayMode: DayMode,
        dayStateLabel: String = "",
        dayGuidance: String,
        dayGuidanceDetail: String,
        nextActionTitle: String,
        nextActionSubtitle: String,
        nextActionTime: String?,
        nextActionKind: NextActionKind,
        nextActionPhase: NextActionPhase = .none,
        completedItems: Int,
        totalItems: Int,
        updatedAt: Date,
        schemaVersion: Int = WeekFitWidgetSnapshot.currentSchemaVersion
    ) {
        self.dateKey = dateKey
        self.activityProgress = Self.clamp01(activityProgress)
        self.activityCalories = max(0, activityCalories)
        self.activityGoal = max(0, activityGoal)
        self.hasActivitySignal = hasActivitySignal
        self.nutritionProgress = Self.clamp01(nutritionProgress)
        self.consumedCalories = max(0, consumedCalories)
        self.remainingCalories = remainingCalories
        self.hasNutritionSignal = hasNutritionSignal
        self.recoveryScore = recoveryScore.map { min(100, max(0, $0)) }
        self.sleepHours = sleepHours
        self.recoveryLabel = recoveryLabel
        self.hasRecoverySignal = hasRecoverySignal
        self.dayMode = dayMode
        self.dayStateLabel = dayStateLabel
        self.dayGuidance = dayGuidance
        self.dayGuidanceDetail = dayGuidanceDetail
        self.nextActionTitle = nextActionTitle
        self.nextActionSubtitle = nextActionSubtitle
        self.nextActionTime = nextActionTime
        self.nextActionKind = nextActionKind
        self.nextActionPhase = nextActionPhase
        self.completedItems = max(0, completedItems)
        self.totalItems = max(0, totalItems)
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }

    public var hasNextAction: Bool {
        nextActionKind != .none && !nextActionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > 6 * 60 * 60
    }

    public var progressSummary: String {
        "\(completedItems) of \(totalItems) done"
    }

    public static func placeholderEmpty(now: Date = Date()) -> WeekFitWidgetSnapshot {
        WeekFitWidgetSnapshot(
            dateKey: Self.dayKey(for: now),
            activityProgress: 0,
            activityCalories: 0,
            activityGoal: 0,
            hasActivitySignal: false,
            nutritionProgress: 0,
            consumedCalories: 0,
            remainingCalories: 0,
            hasNutritionSignal: false,
            recoveryScore: nil,
            sleepHours: nil,
            recoveryLabel: nil,
            hasRecoverySignal: false,
            dayMode: .empty,
            dayStateLabel: "All clear",
            dayGuidance: "Nothing urgent now",
            dayGuidanceDetail: "",
            nextActionTitle: "",
            nextActionSubtitle: "",
            nextActionTime: nil,
            nextActionKind: .none,
            nextActionPhase: .none,
            completedItems: 0,
            totalItems: 0,
            updatedAt: now
        )
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    public static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    enum CodingKeys: String, CodingKey {
        case dateKey, activityProgress, activityCalories, activityGoal, hasActivitySignal
        case nutritionProgress, consumedCalories, remainingCalories, hasNutritionSignal
        case recoveryScore, sleepHours, recoveryLabel, hasRecoverySignal
        case dayMode, dayStateLabel, dayGuidance, dayGuidanceDetail
        case nextActionTitle, nextActionSubtitle, nextActionTime, nextActionKind, nextActionPhase
        case completedItems, totalItems, updatedAt, schemaVersion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try c.decode(String.self, forKey: .dateKey)
        activityProgress = Self.clamp01(try c.decode(Double.self, forKey: .activityProgress))
        activityCalories = try c.decode(Int.self, forKey: .activityCalories)
        activityGoal = try c.decode(Int.self, forKey: .activityGoal)
        hasActivitySignal = try c.decode(Bool.self, forKey: .hasActivitySignal)
        nutritionProgress = Self.clamp01(try c.decode(Double.self, forKey: .nutritionProgress))
        consumedCalories = try c.decode(Int.self, forKey: .consumedCalories)
        remainingCalories = try c.decode(Int.self, forKey: .remainingCalories)
        hasNutritionSignal = try c.decode(Bool.self, forKey: .hasNutritionSignal)
        recoveryScore = try c.decodeIfPresent(Int.self, forKey: .recoveryScore)
        sleepHours = try c.decodeIfPresent(Double.self, forKey: .sleepHours)
        recoveryLabel = try c.decodeIfPresent(String.self, forKey: .recoveryLabel)
        hasRecoverySignal = try c.decode(Bool.self, forKey: .hasRecoverySignal)
        dayMode = try c.decode(DayMode.self, forKey: .dayMode)
        dayStateLabel = try c.decodeIfPresent(String.self, forKey: .dayStateLabel) ?? ""
        dayGuidance = try c.decode(String.self, forKey: .dayGuidance)
        dayGuidanceDetail = try c.decode(String.self, forKey: .dayGuidanceDetail)
        nextActionTitle = try c.decode(String.self, forKey: .nextActionTitle)
        nextActionSubtitle = try c.decode(String.self, forKey: .nextActionSubtitle)
        nextActionTime = try c.decodeIfPresent(String.self, forKey: .nextActionTime)
        nextActionKind = try c.decode(NextActionKind.self, forKey: .nextActionKind)
        if let phase = try c.decodeIfPresent(NextActionPhase.self, forKey: .nextActionPhase) {
            nextActionPhase = phase
        } else if nextActionKind != .none {
            nextActionPhase = .upcoming
        } else {
            nextActionPhase = .none
        }
        completedItems = try c.decode(Int.self, forKey: .completedItems)
        totalItems = try c.decode(Int.self, forKey: .totalItems)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}
