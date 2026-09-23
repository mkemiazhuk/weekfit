import Foundation

/// Pure calendar / enrollment / completion rules for the 7-day challenge.
enum RecoveryChallengeEngine {

    /// Morning confirmation for bedtime tasks is allowed until this local hour (exclusive).
    static let morningConfirmDeadlineHour = 12

    // MARK: - Calendar helpers

    static func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        let calendar = calendar(for: timeZone)
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func startOfDay(for date: Date, timeZone: TimeZone) -> Date {
        calendar(for: timeZone).startOfDay(for: date)
    }

    /// Day index 1…7 for `instant`, or `nil` if outside the personal challenge window.
    static func challengeDayIndex(
        for instant: Date,
        participation: RecoveryChallengeParticipation
    ) -> Int? {
        let timeZone = participation.timeZone
        let calendar = calendar(for: timeZone)
        guard let startDay = dateFromDayKey(participation.startDayKey, timeZone: timeZone) else {
            return nil
        }
        let start = calendar.startOfDay(for: startDay)
        let current = calendar.startOfDay(for: instant)
        guard let days = calendar.dateComponents([.day], from: start, to: current).day else {
            return nil
        }
        let index = days + 1
        guard (1...RecoveryChallengeConfig.dayCount).contains(index) else { return nil }
        return index
    }

    static func dayKey(
        forChallengeDayIndex index: Int,
        participation: RecoveryChallengeParticipation
    ) -> String? {
        guard (1...RecoveryChallengeConfig.dayCount).contains(index) else { return nil }
        let timeZone = participation.timeZone
        guard let startDay = dateFromDayKey(participation.startDayKey, timeZone: timeZone) else {
            return nil
        }
        let calendar = calendar(for: timeZone)
        guard let day = calendar.date(byAdding: .day, value: index - 1, to: calendar.startOfDay(for: startDay)) else {
            return nil
        }
        return dayKey(for: day, timeZone: timeZone)
    }

    /// True once the personal 7 calendar days have elapsed (start of day 8).
    /// Day 1/6 morning confirm closes during days 2 and 7 respectively, so it never extends past day 7.
    static func isPersonalChallengeFinished(
        now: Date,
        participation: RecoveryChallengeParticipation
    ) -> Bool {
        let timeZone = participation.timeZone
        let calendar = calendar(for: timeZone)
        guard let startDay = dateFromDayKey(participation.startDayKey, timeZone: timeZone),
              let day8 = calendar.date(
                byAdding: .day,
                value: RecoveryChallengeConfig.dayCount,
                to: calendar.startOfDay(for: startDay)
              )
        else {
            return false
        }
        return calendar.startOfDay(for: now) >= day8
    }

    // MARK: - Enrollment

    /// All seven challenge calendar days must fit before `eventEnd`.
    static func canEnroll(
        now: Date,
        eventStart: Date,
        eventEnd: Date,
        timeZone: TimeZone
    ) -> Bool {
        guard now >= eventStart, now < eventEnd else { return false }
        let calendar = calendar(for: timeZone)
        let startOfToday = calendar.startOfDay(for: now)
        guard let day7Start = calendar.date(
            byAdding: .day,
            value: RecoveryChallengeConfig.dayCount - 1,
            to: startOfToday
        ) else {
            return false
        }
        // Day 6 morning confirm closes at noon on day 7 — still inside the 7-day span.
        return day7Start < eventEnd
    }

    static func enroll(
        now: Date = Date(),
        timeZone: TimeZone = .current,
        eventID: String = RecoveryChallengeConfig.eventID,
        window: (start: Date, end: Date)?,
        taskDefinitionVersion: RecoveryChallengeTaskDefinitionVersion = .current
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeEnrollmentError> {
        guard let window else { return .failure(.featureUnavailable) }
        guard now >= window.start, now < window.end else {
            return .failure(.outsideEventWindow)
        }
        guard canEnroll(now: now, eventStart: window.start, eventEnd: window.end, timeZone: timeZone) else {
            return .failure(.sevenDaysDoNotFit)
        }
        let participation = RecoveryChallengeParticipation(
            eventID: eventID,
            enrolledAt: now,
            timeZoneIdentifier: timeZone.identifier,
            startDayKey: dayKey(for: now, timeZone: timeZone),
            taskDefinitionVersion: taskDefinitionVersion.rawValue
        )
        return .success(participation)
    }

    // MARK: - Journey

    static func journeyState(
        dayIndex: Int,
        now: Date,
        participation: RecoveryChallengeParticipation
    ) -> RecoveryChallengeJourneyDayState {
        guard (1...RecoveryChallengeConfig.dayCount).contains(dayIndex) else { return .future }
        if participation.hasCompleted(dayIndex: dayIndex) {
            return .completed
        }
        if morningConfirmableDayIndex(now: now, participation: participation) == dayIndex {
            return .awaitingMorningConfirm
        }
        if let current = challengeDayIndex(for: now, participation: participation) {
            if dayIndex == current { return .current }
            if dayIndex > current { return .future }
            return .missed
        }
        if isPersonalChallengeFinished(now: now, participation: participation) {
            return .missed
        }
        return .future
    }

    // MARK: - Morning confirm (Days 1 & 6 in v2)

    static func morningConfirmableDayIndex(
        now: Date,
        participation: RecoveryChallengeParticipation
    ) -> Int? {
        let version = participation.resolvedTaskVersion
        for day in [1, 6] {
            guard allowsMorningConfirmation(dayIndex: day, version: version) else { continue }
            guard !participation.hasCompleted(dayIndex: day) else { continue }
            guard !participation.hasDeclinedMorningConfirm(dayIndex: day) else { continue }
            guard isWithinMorningConfirmWindow(
                forActionDayIndex: day,
                now: now,
                participation: participation
            ) else { continue }
            return day
        }
        return nil
    }

    static func allowsMorningConfirmation(
        dayIndex: Int,
        version: RecoveryChallengeTaskDefinitionVersion
    ) -> Bool {
        RecoveryChallengeTaskCatalog.definition(dayIndex: dayIndex, version: version)?
            .allowsMorningConfirmation == true
    }

    /// Bedtime task for `actionDayIndex` may be confirmed on the next calendar morning until 12:00 enrollment TZ.
    static func isWithinMorningConfirmWindow(
        forActionDayIndex actionDayIndex: Int,
        now: Date,
        participation: RecoveryChallengeParticipation
    ) -> Bool {
        guard allowsMorningConfirmation(
            dayIndex: actionDayIndex,
            version: participation.resolvedTaskVersion
        ) else { return false }
        let tz = participation.timeZone
        let calendar = calendar(for: tz)
        guard let actionDayKey = dayKey(forChallengeDayIndex: actionDayIndex, participation: participation),
              let actionDay = dateFromDayKey(actionDayKey, timeZone: tz)
        else { return false }
        guard let nextMorning = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: actionDay)) else {
            return false
        }
        let morningStart = calendar.startOfDay(for: nextMorning)
        var deadlineComps = calendar.dateComponents([.year, .month, .day], from: morningStart)
        deadlineComps.hour = morningConfirmDeadlineHour
        deadlineComps.minute = 0
        deadlineComps.second = 0
        guard let deadline = calendar.date(from: deadlineComps) else { return false }
        return now >= morningStart && now < deadline
    }

    // MARK: - Event completion gate

    static func isInsideEventWindow(now: Date, window: (start: Date, end: Date)?) -> Bool {
        guard let window else { return false }
        return now >= window.start && now < window.end
    }

    // MARK: - Completion

    static func canComplete(
        dayIndex: Int,
        now: Date,
        participation: RecoveryChallengeParticipation,
        window: (start: Date, end: Date)? = nil
    ) -> Result<Void, RecoveryChallengeCompletionError> {
        if let window, !isInsideEventWindow(now: now, window: window) {
            return .failure(.outsideEventWindow)
        }
        guard (1...RecoveryChallengeConfig.dayCount).contains(dayIndex) else {
            return .failure(.notCurrentDay)
        }
        if participation.hasCompleted(dayIndex: dayIndex) {
            return .failure(.alreadyCompleted)
        }

        // Narrow bedtime exception: confirm previous night until noon.
        if morningConfirmableDayIndex(now: now, participation: participation) == dayIndex {
            return .success(())
        }

        if isPersonalChallengeFinished(now: now, participation: participation) {
            return .failure(.challengeFinished)
        }
        guard let current = challengeDayIndex(for: now, participation: participation) else {
            if let start = dateFromDayKey(participation.startDayKey, timeZone: participation.timeZone) {
                let calendar = calendar(for: participation.timeZone)
                if calendar.startOfDay(for: now) < calendar.startOfDay(for: start) {
                    return .failure(.futureDayLocked)
                }
            }
            return .failure(.challengeFinished)
        }
        if dayIndex > current {
            return .failure(.futureDayLocked)
        }
        if dayIndex < current {
            return .failure(.notCurrentDay)
        }

        // v2 task prerequisites (planning alone never completes).
        if participation.resolvedTaskVersion == .v2 {
            if dayIndex == 5, day5MarkedBreakCount(participation) < 3 {
                return .failure(.day5BreaksIncomplete)
            }
            if dayIndex == 7, participation.day7SelectedFavoriteDayIndex == nil {
                return .failure(.day7FavoriteMissing)
            }
        }

        return .success(())
    }

    /// Completes a day. For v1 Day 1, selecting a wind-down time still *is* completion.
    /// For v2, callers must pass an explicit completion — planning is a separate API.
    static func completing(
        dayIndex: Int,
        now: Date,
        participation: RecoveryChallengeParticipation,
        windDownMinuteOfDay: Int? = nil,
        windDownTargetDayKey: String? = nil,
        chosenHabitID: String? = nil,
        window: (start: Date, end: Date)? = nil
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError> {
        switch canComplete(dayIndex: dayIndex, now: now, participation: participation, window: window) {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }

        var updated = participation
        let version = participation.resolvedTaskVersion

        if version == .v1 {
            guard let task = RecoveryChallengeTaskID(rawValue: dayIndex) else {
                return .failure(.notCurrentDay)
            }
            if task.requiresTimeInput {
                guard let windDownMinuteOfDay else { return .failure(.missingRequiredInput) }
                updated.windDownMinuteOfDay = windDownMinuteOfDay
                updated.windDownTargetDayKey = windDownTargetDayKey
                    ?? dayKey(for: now, timeZone: participation.timeZone)
                updated.plannedMinuteOfDay = updated.windDownMinuteOfDay
                updated.plannedTargetDayKey = updated.windDownTargetDayKey
            }
            if task.requiresHabitChoice {
                guard let chosenHabitID, RecoveryChallengeHabitID(rawValue: chosenHabitID) != nil else {
                    return .failure(.missingRequiredInput)
                }
                updated.chosenHabitID = chosenHabitID
                updated.day7SelectedFavoriteDayIndex = habitDayIndex(for: chosenHabitID)
            }
        } else {
            // v2: optional habit on Day 7 completion only when provided; selection alone is separate.
            if dayIndex == 7, let chosenHabitID {
                updated.chosenHabitID = chosenHabitID
            }
        }

        if !updated.completedDayIndices.contains(dayIndex) {
            updated.completedDayIndices.append(dayIndex)
            updated.completedDayIndices.sort()
        }
        return .success(updated)
    }

    /// Saves an optional plan without completing the day (v2).
    static func savingPlan(
        minuteOfDay: Int,
        targetDayKey: String,
        to participation: RecoveryChallengeParticipation
    ) -> RecoveryChallengeParticipation {
        var next = participation
        next.plannedMinuteOfDay = minuteOfDay
        next.plannedTargetDayKey = targetDayKey
        next.windDownMinuteOfDay = minuteOfDay
        next.windDownTargetDayKey = targetDayKey
        return next
    }

    static func togglingDay5Break(
        breakIndex: Int,
        enabled: Bool,
        on participation: RecoveryChallengeParticipation
    ) -> RecoveryChallengeParticipation {
        guard (0..<3).contains(breakIndex) else { return participation }
        var bits = day5BreakMask(from: participation.day5BreakCount)
        if enabled {
            bits.insert(breakIndex)
        } else {
            bits.remove(breakIndex)
        }
        var next = participation
        next.day5BreakCount = day5BreakBitsValue(from: bits)
        return next
    }

    static func day5BreakMask(from stored: Int) -> Set<Int> {
        var set = Set<Int>()
        if stored & 1 != 0 { set.insert(0) }
        if stored & 2 != 0 { set.insert(1) }
        if stored & 4 != 0 { set.insert(2) }
        return set
    }

    static func day5BreakBitsValue(from bits: Set<Int>) -> Int {
        var value = 0
        if bits.contains(0) { value |= 1 }
        if bits.contains(1) { value |= 2 }
        if bits.contains(2) { value |= 4 }
        return value
    }

    static func day5MarkedBreakCount(_ participation: RecoveryChallengeParticipation) -> Int {
        day5BreakMask(from: participation.day5BreakCount).count
    }

    static func selectingDay7Favorite(
        dayIndex: Int,
        on participation: RecoveryChallengeParticipation
    ) -> RecoveryChallengeParticipation {
        guard (1...6).contains(dayIndex) else { return participation }
        var next = participation
        next.day7SelectedFavoriteDayIndex = dayIndex
        return next
    }

    static func decliningMorningConfirm(
        dayIndex: Int,
        on participation: RecoveryChallengeParticipation
    ) -> RecoveryChallengeParticipation {
        var next = participation
        if !next.declinedMorningConfirmDayIndices.contains(dayIndex) {
            next.declinedMorningConfirmDayIndices.append(dayIndex)
            next.declinedMorningConfirmDayIndices.sort()
        }
        return next
    }

    static func savingChosenHabit(
        habitID: String?,
        on participation: RecoveryChallengeParticipation
    ) -> RecoveryChallengeParticipation {
        var next = participation
        next.chosenHabitID = habitID
        return next
    }

    private static func habitDayIndex(for habitID: String) -> Int? {
        switch RecoveryChallengeHabitID(rawValue: habitID) {
        case .windDownTime: return 1
        case .gentleMovement: return 2
        case .comfortableWalk: return 3
        case .quietUnwind: return 4
        case .feelBasedActivity: return 5
        case .windDownRoutine: return 6
        case .none: return nil
        }
    }

    // MARK: - Surface

    static func todayCardKind(
        now: Date = Date(),
        participation: RecoveryChallengeParticipation?,
        window: (start: Date, end: Date)?,
        timeZone: TimeZone = .current,
        featureAvailable: Bool = RecoveryChallengeConfig.isFeatureAvailable
    ) -> RecoveryChallengeTodayCardKind {
        guard featureAvailable else { return .hidden }

        if let participation, participation.eventID == RecoveryChallengeConfig.eventID {
            if isPersonalChallengeFinished(now: now, participation: participation) {
                if participation.todaySummaryCardDismissed {
                    return .hidden
                }
                if participation.completedCount >= RecoveryChallengeConfig.dayCount {
                    return .hidden
                }
                return .finished(completedCount: participation.completedCount)
            }
            if let dayIndex = challengeDayIndex(for: now, participation: participation) {
                return .participating(
                    dayIndex: dayIndex,
                    todayCompleted: participation.hasCompleted(dayIndex: dayIndex),
                    completedCount: participation.completedCount
                )
            }
            return .hidden
        }

        guard let window else { return .hidden }
        if now < window.start {
            return .hidden
        }
        if canEnroll(now: now, eventStart: window.start, eventEnd: window.end, timeZone: timeZone) {
            return .intro
        }
        return .hidden
    }

    static func screenPhase(
        now: Date = Date(),
        participation: RecoveryChallengeParticipation?
    ) -> RecoveryChallengeScreenPhase {
        guard let participation else { return .overview }
        if isPersonalChallengeFinished(now: now, participation: participation) {
            if let morning = morningConfirmableDayIndex(now: now, participation: participation),
               challengeDayIndex(for: now, participation: participation) == nil {
                return .morningConfirm(dayIndex: morning)
            }
            return .summary(completedCount: participation.completedCount)
        }
        if let dayIndex = challengeDayIndex(for: now, participation: participation) {
            return .active(
                dayIndex: dayIndex,
                todayCompleted: participation.hasCompleted(dayIndex: dayIndex)
            )
        }
        if let morning = morningConfirmableDayIndex(now: now, participation: participation) {
            return .morningConfirm(dayIndex: morning)
        }
        // Clock rolled before enrollment start day — keep Day 1 visible but non-completable.
        if isBeforePersonalStart(now: now, participation: participation) {
            return .active(
                dayIndex: 1,
                todayCompleted: participation.hasCompleted(dayIndex: 1)
            )
        }
        // Enrolled but calendar state unreadable — prefer summary-safe active over join overview.
        return .active(
            dayIndex: 1,
            todayCompleted: participation.hasCompleted(dayIndex: 1)
        )
    }

    /// True when `now` is still on a calendar day before the personal Day 1 start.
    static func isBeforePersonalStart(
        now: Date,
        participation: RecoveryChallengeParticipation
    ) -> Bool {
        guard let start = dateFromDayKey(participation.startDayKey, timeZone: participation.timeZone) else {
            return false
        }
        let calendar = calendar(for: participation.timeZone)
        return calendar.startOfDay(for: now) < calendar.startOfDay(for: start)
    }

    // MARK: - Parsing / formatting

    static func dateFromDayKey(_ dayKey: String, timeZone: TimeZone) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar(for: timeZone).date(from: components)
    }

    /// Alias kept for call sites that used the labeled form.
    static func date(fromDayKey dayKey: String, timeZone: TimeZone) -> Date? {
        dateFromDayKey(dayKey, timeZone: timeZone)
    }

    static func formatMinuteOfDay(_ minuteOfDay: Int, timeZone: TimeZone) -> String {
        let clamped = max(0, min(23 * 60 + 59, minuteOfDay))
        let calendar = calendar(for: timeZone)
        let base = calendar.startOfDay(for: Date())
        guard let date = calendar.date(byAdding: .minute, value: clamped, to: base) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func minuteOfDay(from date: Date, timeZone: TimeZone) -> Int {
        let calendar = calendar(for: timeZone)
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
