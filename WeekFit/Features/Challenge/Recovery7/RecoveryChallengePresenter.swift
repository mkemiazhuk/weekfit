import Foundation
import OSLog

/// Pure presentation rules for Today Recovery Challenge chrome / header entry.
///
/// Three independent decisions:
/// 1. **Availability** — is the event/feature on and enrollment/progress relevant?
/// 2. **Auto intro** — should the Morning-Adjustments-style teaser appear once?
/// 3. **Manual entry** — can the user reopen the challenge from the compact Today chip?
///
/// Intro-shown / deferred / Morning Adjustments suppress **auto intro only**.
/// They must never hide manual access while the challenge remains available.
enum RecoveryChallengePresenter {

    /// Compact header chip / reopen affordance.
    enum HeaderEntry: Equatable, Sendable {
        case hidden
        case invite
        case participating(Active)
        case summary(Summary)

        struct Active: Equatable, Sendable {
            var dayIndex: Int
            var todayCompleted: Bool
            var completedCount: Int
            /// Localization key for today’s task title (never tomorrow’s).
            var taskTitleKey: String
            /// Length always equals `RecoveryChallengeConfig.dayCount`.
            var nodeStates: [RecoveryChallengeJourneyDayState]
        }

        struct Summary: Equatable, Sendable {
            var completedCount: Int
            var isPerfect: Bool
            /// Length always equals `RecoveryChallengeConfig.dayCount`.
            var nodeStates: [RecoveryChallengeJourneyDayState]
        }

        var isVisible: Bool {
            if case .hidden = self { return false }
            return true
        }
    }

    /// Resolved availability for diagnostics and UI gates.
    struct Availability: Equatable, Sendable {
        var featureAvailable: Bool
        var hasEventWindow: Bool
        var canEnroll: Bool
        var isParticipating: Bool
        var isFinished: Bool
        var summaryDismissedFromToday: Bool

        var isChallengeAccessible: Bool {
            featureAvailable && (isParticipating || isFinished || canEnroll)
        }

        var suppressionReasons: [String] {
            var reasons: [String] = []
            if !featureAvailable { reasons.append("feature_unavailable") }
            if !hasEventWindow { reasons.append("no_event_window") }
            if featureAvailable, !isParticipating, !isFinished, !canEnroll {
                reasons.append("enrollment_closed")
            }
            if isFinished, summaryDismissedFromToday {
                reasons.append("summary_dismissed_from_today")
            }
            return reasons
        }
    }

    /// Automatic floating-intro decision (independent of manual entry).
    struct AutoIntroDecision: Equatable, Sendable {
        var shouldShow: Bool
        var suppressionReasons: [String]
    }

    // MARK: - Availability

    static func availability(
        now: Date = Date(),
        participation: RecoveryChallengeParticipation?,
        featureAvailable: Bool = RecoveryChallengeConfig.isFeatureAvailable,
        timeZone: TimeZone = .current
    ) -> Availability {
        let window = RecoveryChallengeConfig.eventWindow(now: now)
        let matching = participation.flatMap { $0.eventID == RecoveryChallengeConfig.eventID ? $0 : nil }
        let participating: Bool = {
            guard let matching else { return false }
            return !RecoveryChallengeEngine.isPersonalChallengeFinished(now: now, participation: matching)
                && RecoveryChallengeEngine.challengeDayIndex(for: now, participation: matching) != nil
        }()
        let finished = matching.map {
            RecoveryChallengeEngine.isPersonalChallengeFinished(now: now, participation: $0)
        } ?? false
        let canEnroll: Bool = {
            guard let window else { return false }
            return RecoveryChallengeEngine.canEnroll(
                now: now,
                eventStart: window.start,
                eventEnd: window.end,
                timeZone: timeZone
            )
        }()

        return Availability(
            featureAvailable: featureAvailable,
            hasEventWindow: window != nil,
            canEnroll: matching == nil && canEnroll,
            isParticipating: matching != nil && participating,
            isFinished: matching != nil && finished,
            summaryDismissedFromToday: matching?.todaySummaryCardDismissed == true
        )
    }

    // MARK: - Auto intro

    /// Whether the Morning-Adjustments-style auto intro overlay may appear.
    static func shouldOfferAutoIntroOverlay(
        now: Date = Date(),
        participation: RecoveryChallengeParticipation?,
        introShownForEventID: String?,
        featureAvailable: Bool = RecoveryChallengeConfig.isFeatureAvailable,
        onboardingComplete: Bool,
        todayVisible: Bool,
        morningAdjustmentsVisible: Bool,
        otherModalVisible: Bool,
        deferredThisVisit: Bool
    ) -> Bool {
        autoIntroDecision(
            now: now,
            participation: participation,
            introShownForEventID: introShownForEventID,
            featureAvailable: featureAvailable,
            onboardingComplete: onboardingComplete,
            todayVisible: todayVisible,
            morningAdjustmentsVisible: morningAdjustmentsVisible,
            otherModalVisible: otherModalVisible,
            deferredThisVisit: deferredThisVisit
        ).shouldShow
    }

    static func autoIntroDecision(
        now: Date = Date(),
        participation: RecoveryChallengeParticipation?,
        introShownForEventID: String?,
        featureAvailable: Bool = RecoveryChallengeConfig.isFeatureAvailable,
        onboardingComplete: Bool,
        todayVisible: Bool,
        morningAdjustmentsVisible: Bool,
        otherModalVisible: Bool,
        deferredThisVisit: Bool,
        timeZone: TimeZone = .current
    ) -> AutoIntroDecision {
        var reasons: [String] = []
        let avail = availability(
            now: now,
            participation: participation,
            featureAvailable: featureAvailable,
            timeZone: timeZone
        )

        if !avail.featureAvailable { reasons.append("feature_unavailable") }
        if !onboardingComplete { reasons.append("onboarding_incomplete") }
        if !todayVisible { reasons.append("today_not_visible") }
        if otherModalVisible { reasons.append("other_modal_visible") }
        if deferredThisVisit { reasons.append("deferred_this_visit_for_morning_adjustments") }
        if morningAdjustmentsVisible { reasons.append("morning_adjustments_visible") }
        if participation != nil {
            reasons.append("already_enrolled")
        } else if !avail.canEnroll {
            reasons.append("not_eligible_to_enroll")
        }
        if introShownForEventID == RecoveryChallengeConfig.eventID {
            reasons.append("intro_already_shown_for_event")
        }

        let shouldShow = reasons.isEmpty
        return AutoIntroDecision(shouldShow: shouldShow, suppressionReasons: reasons)
    }

    // MARK: - Manual entry

    static func headerEntry(
        now: Date = Date(),
        participation: RecoveryChallengeParticipation?,
        featureAvailable: Bool = RecoveryChallengeConfig.isFeatureAvailable,
        timeZone: TimeZone = .current
    ) -> HeaderEntry {
        // Manual entry ignores intro-shown / deferred / Morning Adjustments.
        let avail = availability(
            now: now,
            participation: participation,
            featureAvailable: featureAvailable,
            timeZone: timeZone
        )
        guard avail.featureAvailable else { return .hidden }

        if let participation, participation.eventID == RecoveryChallengeConfig.eventID {
            if RecoveryChallengeEngine.isPersonalChallengeFinished(now: now, participation: participation) {
                if participation.todaySummaryCardDismissed {
                    return .hidden
                }
                return .summary(summaryEntry(now: now, participation: participation))
            }
            if let dayIndex = RecoveryChallengeEngine.challengeDayIndex(
                for: now,
                participation: participation
            ) {
                return .participating(activeEntry(dayIndex: dayIndex, now: now, participation: participation))
            }
            if RecoveryChallengeEngine.isBeforePersonalStart(now: now, participation: participation) {
                return .participating(activeEntry(dayIndex: 1, now: now, participation: participation))
            }
            return .summary(summaryEntry(now: now, participation: participation))
        }

        guard avail.canEnroll else { return .hidden }
        return .invite
    }

    private static func activeEntry(
        dayIndex: Int,
        now: Date,
        participation: RecoveryChallengeParticipation
    ) -> HeaderEntry.Active {
        let version = participation.resolvedTaskVersion
        let titleKey = RecoveryChallengeTaskCatalog.definition(dayIndex: dayIndex, version: version)?.titleKey
            ?? "challenge.recovery7.title"
        return HeaderEntry.Active(
            dayIndex: dayIndex,
            todayCompleted: participation.hasCompleted(dayIndex: dayIndex),
            completedCount: participation.completedCount,
            taskTitleKey: titleKey,
            nodeStates: nodeStates(now: now, participation: participation)
        )
    }

    private static func summaryEntry(
        now: Date,
        participation: RecoveryChallengeParticipation
    ) -> HeaderEntry.Summary {
        HeaderEntry.Summary(
            completedCount: participation.completedCount,
            isPerfect: participation.completedCount >= RecoveryChallengeConfig.dayCount,
            nodeStates: nodeStates(now: now, participation: participation)
        )
    }

    private static func nodeStates(
        now: Date,
        participation: RecoveryChallengeParticipation
    ) -> [RecoveryChallengeJourneyDayState] {
        (1...RecoveryChallengeConfig.dayCount).map { day in
            RecoveryChallengeEngine.journeyState(dayIndex: day, now: now, participation: participation)
        }
    }
}

#if DEBUG
enum RecoveryChallengeDiagnostics {
    private static let logger = Logger(subsystem: "com.weekfit.app", category: "RecoveryChallenge")

    static func logPresentationSnapshot(
        context: String,
        availability: RecoveryChallengePresenter.Availability,
        autoIntro: RecoveryChallengePresenter.AutoIntroDecision,
        manualEntry: RecoveryChallengePresenter.HeaderEntry,
        chromeHidden: Bool,
        deferredThisVisit: Bool,
        introShownEventID: String?,
        debugPreviewActive: Bool
    ) {
        let entryLabel: String = {
            switch manualEntry {
            case .hidden: return "hidden"
            case .invite: return "invite"
            case .participating(let active):
                return "participating(day=\(active.dayIndex),done=\(active.todayCompleted))"
            case .summary(let summary):
                return "summary(completed=\(summary.completedCount))"
            }
        }()
        let availabilitySuppress = availability.suppressionReasons.joined(separator: ",")
        let autoSuppress = autoIntro.suppressionReasons.joined(separator: ",")
        let intro = introShownEventID ?? "nil"

        // Prefer plain print for reliability in Xcode console; also mirror to Logger.
        let line = [
            "RecoveryChallenge[\(context)]",
            "preview=\(debugPreviewActive)",
            "productionEnabled=\(RecoveryChallengeConfig.isProductionEnabled)",
            "featureAvailable=\(availability.featureAvailable)",
            "hasWindow=\(availability.hasEventWindow)",
            "canEnroll=\(availability.canEnroll)",
            "participating=\(availability.isParticipating)",
            "finished=\(availability.isFinished)",
            "available=\(availability.isChallengeAccessible)",
            "availabilitySuppress=\(availabilitySuppress)",
            "autoShow=\(autoIntro.shouldShow)",
            "autoSuppress=\(autoSuppress)",
            "manualEntry=\(entryLabel)",
            "chromeHidden=\(chromeHidden)",
            "deferredVisit=\(deferredThisVisit)",
            "introShown=\(intro)"
        ].joined(separator: " ")
        print(line)
        logger.debug("\(line, privacy: .public)")
    }
}
#endif
