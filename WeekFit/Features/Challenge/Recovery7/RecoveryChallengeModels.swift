import Foundation

struct RecoveryChallengeParticipation: Codable, Equatable, Sendable {
    var eventID: String
    var enrolledAt: Date
    /// IANA timezone captured at enrollment — day boundaries stay stable for this run.
    var timeZoneIdentifier: String
    /// Local calendar day key for day 1 (`yyyy-MM-dd` in enrollment timezone).
    var startDayKey: String
    /// Completed challenge day indices (1…7).
    var completedDayIndices: [Int]
    /// Task catalog version frozen at enrollment. Missing → v1 legacy.
    var taskDefinitionVersion: Int
    /// Optional planned time minutes from midnight (does **not** complete a day).
    var plannedMinuteOfDay: Int?
    /// Calendar day for the planned time (`yyyy-MM-dd`).
    var plannedTargetDayKey: String?
    /// Legacy v1 wind-down fields (kept for existing participants).
    var windDownMinuteOfDay: Int?
    var windDownTargetDayKey: String?
    /// Day 5 partial progress (0…3). Never auto-completes the day.
    var day5BreakCount: Int
    /// Day 7 favorite pick (1…6). Selection alone does not complete Day 7.
    var day7SelectedFavoriteDayIndex: Int?
    /// Habit chosen after the challenge (optional).
    var chosenHabitID: String?
    /// Bedtime days declined via morning “Not this time”.
    var declinedMorningConfirmDayIndices: [Int]
    /// Hide the finished Today entry (summary remains via Profile / deep link).
    var todaySummaryCardDismissed: Bool

    init(
        eventID: String,
        enrolledAt: Date,
        timeZoneIdentifier: String,
        startDayKey: String,
        completedDayIndices: [Int] = [],
        taskDefinitionVersion: Int = RecoveryChallengeTaskDefinitionVersion.current.rawValue,
        plannedMinuteOfDay: Int? = nil,
        plannedTargetDayKey: String? = nil,
        windDownMinuteOfDay: Int? = nil,
        windDownTargetDayKey: String? = nil,
        day5BreakCount: Int = 0,
        day7SelectedFavoriteDayIndex: Int? = nil,
        chosenHabitID: String? = nil,
        declinedMorningConfirmDayIndices: [Int] = [],
        todaySummaryCardDismissed: Bool = false
    ) {
        self.eventID = eventID
        self.enrolledAt = enrolledAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.startDayKey = startDayKey
        self.completedDayIndices = completedDayIndices
        self.taskDefinitionVersion = taskDefinitionVersion
        self.plannedMinuteOfDay = plannedMinuteOfDay
        self.plannedTargetDayKey = plannedTargetDayKey
        self.windDownMinuteOfDay = windDownMinuteOfDay
        self.windDownTargetDayKey = windDownTargetDayKey
        self.day5BreakCount = day5BreakCount
        self.day7SelectedFavoriteDayIndex = day7SelectedFavoriteDayIndex
        self.chosenHabitID = chosenHabitID
        self.declinedMorningConfirmDayIndices = declinedMorningConfirmDayIndices
        self.todaySummaryCardDismissed = todaySummaryCardDismissed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try c.decode(String.self, forKey: .eventID)
        enrolledAt = try c.decode(Date.self, forKey: .enrolledAt)
        timeZoneIdentifier = try c.decode(String.self, forKey: .timeZoneIdentifier)
        startDayKey = try c.decode(String.self, forKey: .startDayKey)
        completedDayIndices = try c.decodeIfPresent([Int].self, forKey: .completedDayIndices) ?? []
        // Missing version = legacy v1 (time-selection semantics). Never reinterpret as v2.
        taskDefinitionVersion = try c.decodeIfPresent(Int.self, forKey: .taskDefinitionVersion)
            ?? RecoveryChallengeTaskDefinitionVersion.v1.rawValue
        plannedMinuteOfDay = try c.decodeIfPresent(Int.self, forKey: .plannedMinuteOfDay)
        plannedTargetDayKey = try c.decodeIfPresent(String.self, forKey: .plannedTargetDayKey)
        windDownMinuteOfDay = try c.decodeIfPresent(Int.self, forKey: .windDownMinuteOfDay)
        windDownTargetDayKey = try c.decodeIfPresent(String.self, forKey: .windDownTargetDayKey)
        day5BreakCount = try c.decodeIfPresent(Int.self, forKey: .day5BreakCount) ?? 0
        day7SelectedFavoriteDayIndex = try c.decodeIfPresent(Int.self, forKey: .day7SelectedFavoriteDayIndex)
        chosenHabitID = try c.decodeIfPresent(String.self, forKey: .chosenHabitID)
        declinedMorningConfirmDayIndices = try c.decodeIfPresent([Int].self, forKey: .declinedMorningConfirmDayIndices) ?? []
        todaySummaryCardDismissed = try c.decodeIfPresent(Bool.self, forKey: .todaySummaryCardDismissed) ?? false
    }

    var completedCount: Int { Set(completedDayIndices).count }

    var resolvedTaskVersion: RecoveryChallengeTaskDefinitionVersion {
        RecoveryChallengeTaskDefinitionVersion(rawValue: taskDefinitionVersion) ?? .v1
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    func hasCompleted(dayIndex: Int) -> Bool {
        completedDayIndices.contains(dayIndex)
    }

    func hasDeclinedMorningConfirm(dayIndex: Int) -> Bool {
        declinedMorningConfirmDayIndices.contains(dayIndex)
    }

    var effectivePlannedMinuteOfDay: Int? {
        plannedMinuteOfDay ?? windDownMinuteOfDay
    }

    var effectivePlannedTargetDayKey: String? {
        plannedTargetDayKey ?? windDownTargetDayKey
    }

    /// Clamp / dedupe persisted fields so partial corruption cannot break progression UI.
    func sanitized() -> RecoveryChallengeParticipation {
        var copy = self
        let dayRange = 1...RecoveryChallengeConfig.dayCount
        copy.completedDayIndices = Array(Set(completedDayIndices.filter { dayRange.contains($0) })).sorted()
        copy.declinedMorningConfirmDayIndices = Array(
            Set(declinedMorningConfirmDayIndices.filter { dayRange.contains($0) })
        ).sorted()
        copy.day5BreakCount = day5BreakCount & 0b111
        if let favorite = day7SelectedFavoriteDayIndex, !(1...6).contains(favorite) {
            copy.day7SelectedFavoriteDayIndex = nil
        }
        if RecoveryChallengeTaskDefinitionVersion(rawValue: taskDefinitionVersion) == nil {
            copy.taskDefinitionVersion = RecoveryChallengeTaskDefinitionVersion.v1.rawValue
        }
        if let planned = plannedMinuteOfDay {
            copy.plannedMinuteOfDay = max(0, min(23 * 60 + 59, planned))
        }
        if let windDown = windDownMinuteOfDay {
            copy.windDownMinuteOfDay = max(0, min(23 * 60 + 59, windDown))
        }
        if timeZoneIdentifier.isEmpty || TimeZone(identifier: timeZoneIdentifier) == nil {
            copy.timeZoneIdentifier = TimeZone.current.identifier
        }
        if !Self.isValidDayKey(copy.startDayKey) {
            let tz = TimeZone(identifier: copy.timeZoneIdentifier) ?? .current
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tz
            let comps = calendar.dateComponents([.year, .month, .day], from: copy.enrolledAt)
            copy.startDayKey = String(
                format: "%04d-%02d-%02d",
                comps.year ?? 0,
                comps.month ?? 0,
                comps.day ?? 0
            )
        }
        return copy
    }

    private static func isValidDayKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), y >= 2000,
              let m = Int(parts[1]), (1...12).contains(m),
              let d = Int(parts[2]), (1...31).contains(d)
        else { return false }
        return true
    }
}

enum RecoveryChallengeTodayCardKind: Equatable, Sendable {
    case hidden
    case intro
    case participating(dayIndex: Int, todayCompleted: Bool, completedCount: Int)
    case finished(completedCount: Int)
}

enum RecoveryChallengeScreenPhase: Equatable, Sendable {
    case overview
    case active(dayIndex: Int, todayCompleted: Bool)
    case morningConfirm(dayIndex: Int)
    case summary(completedCount: Int)
}

enum RecoveryChallengeJourneyDayState: Equatable, Sendable {
    case future
    case current
    case completed
    case missed
    case awaitingMorningConfirm
}

enum RecoveryChallengeEnrollmentError: Error, Equatable, Sendable {
    case featureUnavailable
    case outsideEventWindow
    case sevenDaysDoNotFit
    case alreadyEnrolled
}

enum RecoveryChallengeCompletionError: Error, Equatable, Sendable {
    case notEnrolled
    case challengeFinished
    case notCurrentDay
    case alreadyCompleted
    case futureDayLocked
    case missingRequiredInput
    case day5BreaksIncomplete
    case day7FavoriteMissing
    case outsideEventWindow
    case morningWindowClosed
}
