import Foundation

/// UserDefaults-backed participation for the 7-Day Recovery Challenge.
enum RecoveryChallengeStore {
    static let storageKey = "weekfit.challenge.recovery7.participation.v1"
    static let introShownEventIDKey = "weekfit.challenge.recovery7.introShownEventID.v1"
    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    static func load() -> RecoveryChallengeParticipation? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe()
    }

    static func save(_ participation: RecoveryChallengeParticipation) {
        lock.lock()
        saveUnsafe(participation.sanitized())
        lock.unlock()
    }

    static func clear() {
        lock.lock()
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: introShownEventIDKey)
        lock.unlock()
    }

    /// Event ID for which the automatic Today intro overlay was already shown/dismissed.
    static func introShownEventID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return defaults.string(forKey: introShownEventIDKey)
    }

    static func markIntroShown(eventID: String = RecoveryChallengeConfig.eventID) {
        lock.lock()
        defaults.set(eventID, forKey: introShownEventIDKey)
        lock.unlock()
    }

    /// Clears the auto-intro flag so a later visit can offer it again
    /// (e.g. Morning Adjustments took priority during this visit).
    static func clearIntroShown(eventID: String = RecoveryChallengeConfig.eventID) {
        lock.lock()
        if defaults.string(forKey: introShownEventIDKey) == eventID {
            defaults.removeObject(forKey: introShownEventIDKey)
        }
        lock.unlock()
    }

    @discardableResult
    static func enroll(
        now: Date = Date(),
        timeZone: TimeZone = .current,
        taskDefinitionVersion: RecoveryChallengeTaskDefinitionVersion = .current
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeEnrollmentError> {
        lock.lock()
        defer { lock.unlock() }
        if let existing = loadUnsafe(), existing.eventID == RecoveryChallengeConfig.eventID {
            return .failure(.alreadyEnrolled)
        }
        let result = RecoveryChallengeEngine.enroll(
            now: now,
            timeZone: timeZone,
            window: RecoveryChallengeConfig.eventWindow(now: now),
            taskDefinitionVersion: taskDefinitionVersion
        )
        if case .success(let participation) = result {
            let sanitized = participation.sanitized()
            saveUnsafe(sanitized)
            defaults.set(sanitized.eventID, forKey: introShownEventIDKey)
            return .success(sanitized)
        }
        return result
    }

    /// Saves an optional schedule without completing the day.
    @discardableResult
    static func savePlan(
        minuteOfDay: Int,
        targetDayKey: String
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError> {
        mutateParticipation { participation in
            .success(
                RecoveryChallengeEngine.savingPlan(
                    minuteOfDay: minuteOfDay,
                    targetDayKey: targetDayKey,
                    to: participation
                )
            )
        }
    }

    /// Explicit day completion. Does not treat planning as success for v2.
    @discardableResult
    static func completeCurrentDay(
        now: Date = Date(),
        windDownMinuteOfDay: Int? = nil,
        windDownTargetDayKey: String? = nil,
        chosenHabitID: String? = nil
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError> {
        guard RecoveryChallengeConfig.isFeatureAvailable else {
            return .failure(.outsideEventWindow)
        }
        guard let window = RecoveryChallengeConfig.eventWindow(now: now) else {
            return .failure(.outsideEventWindow)
        }

        return mutateParticipation { participation in
            guard let dayIndex = RecoveryChallengeEngine.challengeDayIndex(
                for: now,
                participation: participation
            ) else {
                if RecoveryChallengeEngine.isPersonalChallengeFinished(now: now, participation: participation) {
                    return .failure(.challengeFinished)
                }
                return .failure(.notCurrentDay)
            }

            return RecoveryChallengeEngine.completing(
                dayIndex: dayIndex,
                now: now,
                participation: participation,
                windDownMinuteOfDay: windDownMinuteOfDay ?? participation.effectivePlannedMinuteOfDay,
                windDownTargetDayKey: windDownTargetDayKey ?? participation.effectivePlannedTargetDayKey,
                chosenHabitID: chosenHabitID ?? participation.chosenHabitID,
                window: window
            )
        }
    }

    @discardableResult
    static func completeDay(
        dayIndex: Int,
        now: Date = Date(),
        chosenHabitID: String? = nil
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError> {
        guard RecoveryChallengeConfig.isFeatureAvailable else {
            return .failure(.outsideEventWindow)
        }
        guard let window = RecoveryChallengeConfig.eventWindow(now: now) else {
            return .failure(.outsideEventWindow)
        }

        return mutateParticipation { participation in
            RecoveryChallengeEngine.completing(
                dayIndex: dayIndex,
                now: now,
                participation: participation,
                windDownMinuteOfDay: participation.effectivePlannedMinuteOfDay,
                windDownTargetDayKey: participation.effectivePlannedTargetDayKey,
                chosenHabitID: chosenHabitID ?? participation.chosenHabitID,
                window: window
            )
        }
    }

    @discardableResult
    static func setDay5Break(
        breakIndex: Int,
        enabled: Bool
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError> {
        mutateParticipation { participation in
            .success(
                RecoveryChallengeEngine.togglingDay5Break(
                    breakIndex: breakIndex,
                    enabled: enabled,
                    on: participation
                )
            )
        }
    }

    @discardableResult
    static func selectDay7Favorite(
        dayIndex: Int
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError> {
        mutateParticipation { participation in
            .success(
                RecoveryChallengeEngine.selectingDay7Favorite(
                    dayIndex: dayIndex,
                    on: participation
                )
            )
        }
    }

    @discardableResult
    static func declineMorningConfirm(
        dayIndex: Int
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError> {
        mutateParticipation { participation in
            .success(
                RecoveryChallengeEngine.decliningMorningConfirm(
                    dayIndex: dayIndex,
                    on: participation
                )
            )
        }
    }

    static func saveChosenHabit(_ habitID: RecoveryChallengeHabitID) {
        _ = mutateParticipation { participation in
            .success(
                RecoveryChallengeEngine.savingChosenHabit(
                    habitID: habitID.rawValue,
                    on: participation
                )
            )
        }
    }

    static func saveChosenHabitID(_ habitID: String?) {
        _ = mutateParticipation { participation in
            .success(
                RecoveryChallengeEngine.savingChosenHabit(habitID: habitID, on: participation)
            )
        }
    }

    static func dismissFinishedTodayCard() {
        _ = mutateParticipation { participation in
            var next = participation
            next.todaySummaryCardDismissed = true
            return .success(next)
        }
    }

    static func todayCardKind(now: Date = Date(), timeZone: TimeZone = .current) -> RecoveryChallengeTodayCardKind {
        RecoveryChallengeEngine.todayCardKind(
            now: now,
            participation: load(),
            window: RecoveryChallengeConfig.eventWindow(now: now),
            timeZone: timeZone,
            featureAvailable: RecoveryChallengeConfig.isFeatureAvailable
        )
    }

    static func headerEntry(now: Date = Date(), timeZone: TimeZone = .current) -> RecoveryChallengePresenter.HeaderEntry {
        RecoveryChallengePresenter.headerEntry(
            now: now,
            participation: load(),
            featureAvailable: RecoveryChallengeConfig.isFeatureAvailable,
            timeZone: timeZone
        )
    }

    #if DEBUG
    static func setDefaultsForTests(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func useStandardDefaultsForTests() {
        lock.lock()
        defaults = .standard
        lock.unlock()
    }

    static func resetAllForTests() {
        clear()
    }

    /// DEBUG-only: replace participation with a fresh v2 enrollment for local preview.
    /// Does not mutate production event configuration.
    @discardableResult
    static func debugResetToFreshV2Enrollment(
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeEnrollmentError> {
        clear()
        return enroll(now: now, timeZone: timeZone, taskDefinitionVersion: .v2)
    }
    #endif

    // MARK: - Internals

    private static func mutateParticipation(
        _ body: (RecoveryChallengeParticipation) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError>
    ) -> Result<RecoveryChallengeParticipation, RecoveryChallengeCompletionError> {
        lock.lock()
        defer { lock.unlock() }
        guard let participation = loadUnsafe() else { return .failure(.notEnrolled) }
        switch body(participation) {
        case .failure(let error):
            return .failure(error)
        case .success(let updated):
            let sanitized = updated.sanitized()
            saveUnsafe(sanitized)
            return .success(sanitized)
        }
    }

    private static func loadUnsafe() -> RecoveryChallengeParticipation? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        guard let decoded = try? JSONDecoder().decode(RecoveryChallengeParticipation.self, from: data) else {
            return nil
        }
        return decoded.sanitized()
    }

    private static func saveUnsafe(_ participation: RecoveryChallengeParticipation) {
        guard let data = try? JSONEncoder().encode(participation.sanitized()) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
