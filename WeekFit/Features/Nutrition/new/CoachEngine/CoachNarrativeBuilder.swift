import Foundation

struct CoachNarrative {
    let title: String
    let message: String
}

enum CoachNarrativeBuilder {

    static func build(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        nutrition: CoachNutritionContext
    ) -> CoachNarrative {

        let profile = CoachActivityProfileResolver.resolve(scenario: scenario)

        switch scenario.stage {
        case .before:
            return beforeNarrative(
                scenario: scenario,
                profile: profile,
                dayContext: dayContext
            )

        case .during:
            return duringNarrative(
                scenario: scenario,
                profile: profile,
                dayContext: dayContext
            )

        case .after:
            return afterNarrative(
                scenario: scenario,
                profile: profile,
                dayContext: dayContext,
                nutrition: nutrition
            )

        case .stable:

            if dayContext.hasMoreLoadAhead {
                return CoachNarrative(
                    title: "Between sessions",
                    message: "No immediate action is needed. Stay consistent and keep energy available for what's ahead."
                )
            }

            if dayContext.hasMeaningfulLoadCompleted {
                return CoachNarrative(
                    title: "Day complete",
                    message: "Today's key work is done. Focus on recovery, hydration and setting yourself up for tomorrow."
                )
            }

            return CoachNarrative(
                title: "Everything looks steady",
                message: "Nothing requires attention right now. Stay active, hydrate well and maintain healthy routines."
            )
        }
    }
}

// MARK: - Stage Narratives

private extension CoachNarrativeBuilder {

    static func beforeNarrative(
        scenario: CoachActivityScenario,
        profile: CoachFuelingActivityProfile,
        dayContext: CoachDayContext
    ) -> CoachNarrative {

        let name = activityName(scenario)
        let duration = durationText(scenario.activity?.effectiveDurationMinutes ?? scenario.activity?.durationMinutes ?? 0)
        let hasEarlierLoad = dayContext.hasMeaningfulLoadCompleted
        let hasMoreAhead = dayContext.hasMoreLoadAhead

        switch profile {

        case .endurance(.cycling):
            return CoachNarrative(
                title: "Prepare for the ride",
                message: dayAwareMessage(
                    base: duration.isEmpty
                        ? "Keep the first part easy and settle into a steady rhythm."
                        : "A \(duration) ride is ahead. Keep the first part easy and settle into a steady rhythm.",
                    hasEarlierLoad: hasEarlierLoad,
                    hasMoreAhead: hasMoreAhead
                )
            )

        case .endurance(.running):
            return CoachNarrative(
                title: "Prepare for the run",
                message: dayAwareMessage(
                    base: duration.isEmpty
                        ? "Start slower than you want to and build only if the body feels good."
                        : "A \(duration) run is ahead. Start slower than you want to and build only if the body feels good.",
                    hasEarlierLoad: hasEarlierLoad,
                    hasMoreAhead: hasMoreAhead
                )
            )

        case .racket(.tennis):
            return CoachNarrative(
                title: "Prepare for tennis",
                message: dayAwareMessage(
                    base: "Use the first games to find rhythm. Play with control before adding intensity.",
                    hasEarlierLoad: hasEarlierLoad,
                    hasMoreAhead: hasMoreAhead
                )
            )

        case .racket(.squash):
            return CoachNarrative(
                title: "Prepare for squash",
                message: dayAwareMessage(
                    base: "Warm up properly and control the opening games. Squash can become intense quickly.",
                    hasEarlierLoad: hasEarlierLoad,
                    hasMoreAhead: hasMoreAhead
                )
            )

        case .strength:
            return CoachNarrative(
                title: "Prepare for \(name)",
                message: dayAwareMessage(
                    base: "Warm up well and keep the first sets controlled. Quality matters more than chasing extra load.",
                    hasEarlierLoad: hasEarlierLoad,
                    hasMoreAhead: hasMoreAhead
                )
            )

        case .heat:
            return CoachNarrative(
                title: "Prepare for heat recovery",
                message: "Treat this as recovery support, not a challenge. Keep it comfortable and stop before it feels stressful."
            )

        case .recovery:
            return recoveryBeforeNarrative(
                scenario: scenario,
                hasEarlierLoad: hasEarlierLoad
            )

        case .endurance(.general), .racket(.general), .other:
            return CoachNarrative(
                title: "Prepare for \(name)",
                message: dayAwareMessage(
                    base: "Start easy, stay controlled and keep this block aligned with the plan.",
                    hasEarlierLoad: hasEarlierLoad,
                    hasMoreAhead: hasMoreAhead
                )
            )
            
        case .breathing:

            if isEvening(scenario) {
                return CoachNarrative(
                    title: "Evening downshift",
                    message: "Use this session to help the body transition into recovery mode and prepare for a calmer evening."
                )
            }

            if isMorning(scenario) {
                return CoachNarrative(
                    title: "Calm start",
                    message: "Use this session to start the day with a calmer mind and steadier focus."
                )
            }

            return CoachNarrative(
                title: "Reset your focus",
                message: "Take a few minutes away from stress and let the nervous system settle."
            )
        }
    }

    static func duringNarrative(
        scenario: CoachActivityScenario,
        profile: CoachFuelingActivityProfile,
        dayContext: CoachDayContext
    ) -> CoachNarrative {

        let name = activityName(scenario)
        let hasEarlierLoad = dayContext.hasMeaningfulLoadCompleted

        switch profile {

        case .endurance(.cycling):
            return CoachNarrative(
                title: "Stay smooth",
                message: hasEarlierLoad
                    ? "You already have load in the day. Keep the ride steady and avoid turning volume into intensity."
                    : "Keep pressure smooth and stay in control. Avoid unnecessary surges."
            )

        case .endurance(.running):
            return CoachNarrative(
                title: "Stay steady",
                message: hasEarlierLoad
                    ? "You already trained earlier today. Keep this run controlled and avoid chasing speed."
                    : "Keep the effort steady, relax your shoulders and do not chase speed today."
            )

        case .racket(.tennis):
            return CoachNarrative(
                title: "Find rhythm",
                message: "Stay relaxed between points and focus on consistency before intensity."
            )

        case .racket(.squash):
            return CoachNarrative(
                title: "Stay efficient",
                message: "Control your breathing, slow down between rallies and avoid making every point all-out."
            )

        case .strength:
            return CoachNarrative(
                title: "\(name) in progress",
                message: "Keep form clean and leave 1–2 reps in reserve. Stop before technique breaks down."
            )

        case .heat:
            return CoachNarrative(
                title: "Keep heat controlled",
                message: "Stay comfortable and end the block before it starts feeling stressful."
            )

        case .recovery:
            return recoveryDuringNarrative(scenario: scenario)

        case .endurance(.general), .racket(.general), .other:
            return CoachNarrative(
                title: "\(name) in progress",
                message: "Keep effort controlled, stay comfortable and finish calmly."
            )
            
        case .breathing:
            return CoachNarrative(
                title: "Stay present",
                message: "There is nothing to achieve here. Let the breath stay comfortable and return your attention whenever the mind drifts."
            )
        }
    }

    static func afterNarrative(
        scenario: CoachActivityScenario,
        profile: CoachFuelingActivityProfile,
        dayContext: CoachDayContext,
        nutrition: CoachNutritionContext
    ) -> CoachNarrative {

        let name = activityName(scenario)
        let hasMoreAhead = dayContext.hasMoreLoadAhead

        switch profile {

        case .endurance(.cycling):
            return CoachNarrative(
                title: "Ride complete",
                message: hasMoreAhead
                    ? "The ride is done. Refill fluids and keep the next block easy."
                    : "The ride is done. Refill fluids and let the body settle now."
            )

        case .endurance(.running):
            return CoachNarrative(
                title: "Run complete",
                message: hasMoreAhead
                    ? "The run is done. Let your breathing settle and avoid adding extra intensity."
                    : "The run is done. Walk for a few minutes and keep the rest of the day easy."
            )

        case .racket(.tennis):
            return CoachNarrative(
                title: "Tennis complete",
                message: "Replace fluids, let the body calm down and avoid another hard session today."
            )

        case .racket(.squash):
            return CoachNarrative(
                title: "Squash complete",
                message: "Rehydrate now and keep the rest of the day easy. Squash adds fatigue quickly."
            )

        case .strength:
            return CoachNarrative(
                title: "\(name) complete",
                message: "The main work is done. Eat protein, drink water and let your heart rate settle."
            )

        case .heat:
            return CoachNarrative(
                title: "Heat recovery complete",
                message: "Let your system settle now. Drink slowly and keep the rest of the day calm."
            )

        case .recovery:
            return recoveryAfterNarrative(scenario: scenario)

        case .endurance(.general), .racket(.general), .other:
            return CoachNarrative(
                title: "\(name) complete",
                message: "Return to the plan, keep the next step simple and avoid unnecessary extra load."
            )
            
        case .breathing:

            if isEvening(scenario) {
                return CoachNarrative(
                    title: "Recovery effect",
                    message: "Your body is shifting into recovery mode. Keep the rest of the evening calm and protect the relaxed state you created."
                )
            }

            if isMorning(scenario) {
                return CoachNarrative(
                    title: "Calmer start",
                    message: "Take this calmer state into the rest of your morning and avoid rushing the next task."
                )
            }

            return CoachNarrative(
                title: "Reset complete",
                message: "The session is finished. Give yourself a few minutes before jumping back into a busy schedule."
            )
        }
    }
}

// MARK: - Recovery Narratives

private extension CoachNarrativeBuilder {

    static func recoveryBeforeNarrative(
        scenario: CoachActivityScenario,
        hasEarlierLoad: Bool
    ) -> CoachNarrative {

        let text = activityText(scenario)

        if isWalk(text) {
            return CoachNarrative(
                title: "Keep the walk easy",
                message: hasEarlierLoad
                    ? "You already have activity load today. This walk should help recovery, not become extra training."
                    : "Use this walk to loosen up and feel better afterwards."
            )
        }

        if isBreathing(text) {
            return CoachNarrative(
                title: "Slow everything down",
                message: "Use this block to calm the nervous system and prepare for better recovery."
            )
        }

        if isStretching(text) {
            return CoachNarrative(
                title: "Restore mobility",
                message: "Focus on range of motion, not intensity. You should feel looser afterwards."
            )
        }

        if isYoga(text) {
            return CoachNarrative(
                title: "Keep yoga gentle",
                message: "Use this session to release tension and finish calmer than you started."
            )
        }

        return CoachNarrative(
            title: "Recovery block",
            message: "This is recovery support, not extra load. Keep it easy and comfortable."
        )
    }

    static func recoveryDuringNarrative(
        scenario: CoachActivityScenario
    ) -> CoachNarrative {

        let text = activityText(scenario)

        if isWalk(text) {
            return CoachNarrative(
                title: "Keep it easy",
                message: "Walk at a pace that feels relaxing. This is for circulation and recovery."
            )
        }

        if isBreathing(text) {
            return CoachNarrative(
                title: "Stay calm",
                message: "Keep breathing slow, steady and comfortable."
            )
        }

        if isStretching(text) || isYoga(text) {
            return CoachNarrative(
                title: "Stay gentle",
                message: "Do not force range. Stop before anything feels sharp or stressful."
            )
        }

        return CoachNarrative(
            title: "Recovery in progress",
            message: "Keep it easy and avoid turning this into training."
        )
    }

    static func recoveryAfterNarrative(
        scenario: CoachActivityScenario
    ) -> CoachNarrative {

        let text = activityText(scenario)

        if isWalk(text) {

            if isEvening(scenario) {
                return CoachNarrative(
                    title: "Walk complete",
                    message: "A relaxed walk can help the body transition into recovery for the night. Keep the evening calm from here."
                )
            }

            if isMorning(scenario) {
                return CoachNarrative(
                    title: "Walk complete",
                    message: "A relaxed walk is a great way to wake the body without adding stress. Take that momentum into the day."
                )
            }

            return CoachNarrative(
                title: "Walk complete",
                message: "Keep the benefit by staying relaxed and avoiding extra intensity."
            )
        }

        if isBreathing(text) {
            return CoachNarrative(
                title: "Breathing complete",
                message: "Stay calm now and protect the downshift you created."
            )
        }

        return CoachNarrative(
            title: "Recovery complete",
            message: "Keep the rest of the day simple and avoid adding unnecessary load."
        )
    }
}

// MARK: - Helpers

private extension CoachNarrativeBuilder {
    
    static func isEvening(
        _ scenario: CoachActivityScenario
    ) -> Bool {
        switch scenario.dayTime {
        case .evening, .lateEvening, .night:
            return true
        default:
            return false
        }
    }

    static func isMorning(
        _ scenario: CoachActivityScenario
    ) -> Bool {
        switch scenario.dayTime {
        case .morning:
            return true
        default:
            return false
        }
    }

    static func activityName(
        _ scenario: CoachActivityScenario
    ) -> String {
        let raw = scenario.activity?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Activity" : raw
    }

    static func activityText(
        _ scenario: CoachActivityScenario
    ) -> String {
        "\(scenario.activity?.title ?? "") \(scenario.activity?.type ?? "")"
            .lowercased()
    }

    static func dayAwareMessage(
        base: String,
        hasEarlierLoad: Bool,
        hasMoreAhead: Bool
    ) -> String {
        if hasEarlierLoad && hasMoreAhead {
            return "You already trained earlier today and still have more ahead. \(base)"
        }

        if hasEarlierLoad {
            return "You already have activity load today. \(base)"
        }

        if hasMoreAhead {
            return "There is more planned later today. \(base)"
        }

        return base
    }

    static func durationText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "" }

        let hours = minutes / 60
        let remainder = minutes % 60

        if hours > 0 && remainder > 0 {
            return "\(hours)h \(remainder)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }

    static func isWalk(_ text: String) -> Bool {
        text.contains("walk") ||
        text.contains("walking") ||
        text.contains("hike")
    }

    static func isStretching(_ text: String) -> Bool {
        text.contains("stretch") ||
        text.contains("mobility")
    }

    static func isYoga(_ text: String) -> Bool {
        text.contains("yoga")
    }

    static func isBreathing(_ text: String) -> Bool {
        text.contains("breath") ||
        text.contains("breathing")
    }
}
