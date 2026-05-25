import Foundation
import SwiftUI

final class WorkoutRecoveryCoachService {

    private let preActivityWindow: TimeInterval = 75 * 60
    private let recoveryWindow: TimeInterval = 120 * 60
    private let missedWindow: TimeInterval = 45 * 60

    private let maxTitleCharacters = 26
    private let maxActionCharacters = 32
    private let maxMessageCharacters = 145

    func generate(
        plannedActivities: [PlannedActivity],
        selectedDate: Date,
        now: Date = Date(),
        sleepHours: Double,
        activeCalories: Double
    ) -> WorkoutRecoveryCoachCard {

        let physicalActivities = plannedActivities
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .filter { isPhysicalActivity($0) }
            .sorted { $0.date < $1.date }

        let phase = dayPhase(now)

        if let live = liveActivity(from: physicalActivities, now: now) {
            return liveActivityMessage(for: live, sleepHours: sleepHours, phase: phase)
        }

        if let soon = upcomingSoonActivity(from: physicalActivities, now: now) {
            return preActivityMessage(for: soon, sleepHours: sleepHours, phase: phase)
        }

        if let completed = recentlyCompletedActivity(from: physicalActivities, now: now) {
            return recoveryMessage(for: completed, sleepHours: sleepHours, phase: phase)
        }

        if let missed = recentlyMissedActivity(from: physicalActivities, now: now) {
            return makeCard(
                state: .recentlyMissed,
                title: "Plan changed",
                action: "Keep it easy",
                message: "\(missed.title) didn’t happen. Don’t turn it into pressure now — keep the next step simple and light.",
                focusActivity: missed
            )
        }

        if let skipped = recentlySkippedActivity(from: physicalActivities, now: now) {
            return makeCard(
                state: .recentlyMissed,
                title: "Good adjustment",
                action: "Stay gentle",
                message: "\(skipped.title) was skipped. If your body needed that, it was the right call. Keep the rest of the day simple.",
                focusActivity: skipped
            )
        }

        if let later = laterTodayActivity(from: physicalActivities, now: now) {
            return laterTodayMessage(for: later, sleepHours: sleepHours, phase: phase)
        }

        if let completedEarlier = completedEarlierActivity(from: physicalActivities, now: now) {
            return completedEarlierMessage(for: completedEarlier, sleepHours: sleepHours, phase: phase)
        }

        if sleepHours > 0 && sleepHours < 6 {
            return makeCard(
                state: .sleep,
                title: "Low recovery",
                action: "Reduce intensity",
                message: "Sleep was short, so recovery capacity is lower today. Keep movement easy and avoid forcing intensity.",
                focusActivity: nil
            )
        }

        if physicalActivities.isEmpty {
            return noWorkoutMessage(for: phase, activeCalories: activeCalories)
        }

        if activeCalories < 180 {
            return movementMessage(for: phase)
        }

        return makeCard(
            state: .balanced,
            title: "Looks steady",
            action: "Keep your rhythm",
            message: "Your day looks balanced so far. Stay consistent, hydrate normally, and don’t overcomplicate recovery.",
            focusActivity: nil
        )
    }

    private func liveActivityMessage(
        for activity: PlannedActivity,
        sleepHours: Double,
        phase: CoachDayPhase
    ) -> WorkoutRecoveryCoachCard {

        let load = activityLoad(activity)

        if sleepHours > 0 && sleepHours < 6 {
            return makeCard(
                state: .liveActivity,
                title: "Stay controlled",
                action: "Don’t chase intensity",
                message: "\(activity.title) is happening now. With short sleep, keep the effort controlled and avoid pushing harder than needed.",
                focusActivity: activity
            )
        }

        switch load {
        case .veryLongEndurance:
            return makeCard(
                state: .liveActivity,
                title: "Long session",
                action: "Pace and hydrate",
                message: "\(activity.title) is a long effort. Keep the pace steady, sip fluids, and don’t wait until you feel empty.",
                focusActivity: activity
            )

        case .longEndurance:
            return makeCard(
                state: .liveActivity,
                title: "Steady effort",
                action: "Fuel calmly",
                message: "\(activity.title) is active now. Keep it smooth, drink steadily, and protect energy for the final part.",
                focusActivity: activity
            )

        case .highIntensity:
            return makeCard(
                state: .liveActivity,
                title: "High effort",
                action: "Control the peak",
                message: "\(activity.title) is intense. Focus on clean effort, controlled breathing, and don’t turn every minute into a max push.",
                focusActivity: activity
            )

        case .strength:
            return makeCard(
                state: .liveActivity,
                title: "Strength work",
                action: "Quality over rush",
                message: "\(activity.title) is happening now. Keep the reps clean, rest enough, and avoid forcing volume if form drops.",
                focusActivity: activity
            )

        case .light:
            return makeCard(
                state: .liveActivity,
                title: "Easy movement",
                action: "Keep it relaxed",
                message: "\(activity.title) is active now. This is about circulation and rhythm, not pushing the body harder.",
                focusActivity: activity
            )

        case .moderate:
            return makeCard(
                state: .liveActivity,
                title: "In session",
                action: "Find a rhythm",
                message: "\(activity.title) is happening now. Settle into a pace you can hold and keep the effort smooth.",
                focusActivity: activity
            )
        }
    }

    private func preActivityMessage(
        for activity: PlannedActivity,
        sleepHours: Double,
        phase: CoachDayPhase
    ) -> WorkoutRecoveryCoachCard {

        let load = activityLoad(activity)

        if sleepHours > 0 && sleepHours < 6 {
            return makeCard(
                state: .preActivity,
                title: "Be careful today",
                action: "Lower the ceiling",
                message: "\(timeString(activity.date)) \(activity.title) is soon. Short sleep means lower recovery, so keep the session controlled.",
                focusActivity: activity
            )
        }

        switch load {
        case .veryLongEndurance:
            return makeCard(
                state: .preActivity,
                title: "Big session soon",
                action: "Start fueled",
                message: "\(timeString(activity.date)) \(activity.title) is coming. Eat something steady, hydrate early, and avoid starting depleted.",
                focusActivity: activity
            )

        case .longEndurance:
            return makeCard(
                state: .preActivity,
                title: "Endurance ahead",
                action: "Prepare calmly",
                message: "\(timeString(activity.date)) \(activity.title) is soon. Keep the next hour simple: fluids, easy food, no rush.",
                focusActivity: activity
            )

        case .highIntensity:
            return makeCard(
                state: .preActivity,
                title: "Intensity ahead",
                action: "Arrive fresh",
                message: "\(timeString(activity.date)) \(activity.title) is soon. Avoid heavy food now and give your body a clean start.",
                focusActivity: activity
            )

        case .strength:
            return makeCard(
                state: .preActivity,
                title: "Lift coming up",
                action: "Prime energy",
                message: "\(timeString(activity.date)) \(activity.title) is soon. A light carb-protein meal and water can help you feel stronger.",
                focusActivity: activity
            )

        case .light:
            return makeCard(
                state: .preActivity,
                title: "Easy session soon",
                action: "Stay relaxed",
                message: "\(timeString(activity.date)) \(activity.title) is coming. No big preparation needed — just arrive comfortable.",
                focusActivity: activity
            )

        case .moderate:
            return makeCard(
                state: .preActivity,
                title: "Coming up soon",
                action: "Arrive fresh",
                message: "\(timeString(activity.date)) \(activity.title) is coming up. Keep the next hour light and give yourself an easy start.",
                focusActivity: activity
            )
        }
    }

    private func recoveryMessage(
        for activity: PlannedActivity,
        sleepHours: Double,
        phase: CoachDayPhase
    ) -> WorkoutRecoveryCoachCard {

        let load = activityLoad(activity)

        if phase == .night {
            return makeCard(
                state: .sleep,
                title: "Recovery now",
                action: "Wind down",
                message: "\(activity.title) is done. Keep the night quiet now — recovery improves when the body can fully settle.",
                focusActivity: activity
            )
        }

        if sleepHours > 0 && sleepHours < 6 {
            return makeCard(
                state: .recovery,
                title: "Protect recovery",
                action: "Refuel and slow down",
                message: "\(activity.title) is done. With short sleep, recovery needs extra support: fluids, protein, and a calmer pace.",
                focusActivity: activity
            )
        }

        switch load {
        case .veryLongEndurance:
            return makeCard(
                state: .recovery,
                title: "Big effort done",
                action: "Refuel steadily",
                message: "\(activity.title) was a long session. Rehydrate, add sodium if needed, and eat enough carbs with protein.",
                focusActivity: activity
            )

        case .longEndurance:
            return makeCard(
                state: .recovery,
                title: "Endurance done",
                action: "Restore energy",
                message: "\(activity.title) is done. Your body needs fluids and steady food now, not just willpower to keep going.",
                focusActivity: activity
            )

        case .highIntensity:
            return makeCard(
                state: .recovery,
                title: "High load done",
                action: "Calm the system",
                message: "\(activity.title) is done. Let your heart rate and nervous system come down before stacking more stress.",
                focusActivity: activity
            )

        case .strength:
            return makeCard(
                state: .recovery,
                title: "Strength done",
                action: "Protein and rest",
                message: "\(activity.title) is done. Prioritize protein, water, and a slower pace — fatigue may show up later.",
                focusActivity: activity
            )

        case .light:
            return makeCard(
                state: .recovery,
                title: "Good reset",
                action: "Keep it natural",
                message: "\(activity.title) is done. This was light recovery movement, so no big protocol needed — just stay steady.",
                focusActivity: activity
            )

        case .moderate:
            return makeCard(
                state: .recovery,
                title: "Nice work",
                action: "Recover smoothly",
                message: "\(activity.title) is done. Take water, eat something balanced, and let the body come down naturally.",
                focusActivity: activity
            )
        }
    }

    private func laterTodayMessage(
        for activity: PlannedActivity,
        sleepHours: Double,
        phase: CoachDayPhase
    ) -> WorkoutRecoveryCoachCard {

        let load = activityLoad(activity)

        if sleepHours > 0 && sleepHours < 6 {
            return makeCard(
                state: .laterToday,
                title: "Adjust the plan",
                action: "Keep it lighter",
                message: "\(activity.title) is later today, but sleep was short. Treat it as controlled movement, not a performance test.",
                focusActivity: activity
            )
        }

        switch phase {
        case .morning:
            return makeCard(
                state: .laterToday,
                title: "Later today",
                action: load == .veryLongEndurance ? "Fuel early" : "Build gently",
                message: "\(activity.title) is later today. Start easy now so you still have energy when it matters.",
                focusActivity: activity
            )

        case .afternoon:
            return makeCard(
                state: .laterToday,
                title: "Keep energy",
                action: "Don’t drain early",
                message: "\(activity.title) is still ahead. Keep this part of the day steady, hydrated, and not too heavy.",
                focusActivity: activity
            )

        case .evening:
            return makeCard(
                state: .laterToday,
                title: "Evening session",
                action: "Keep it controlled",
                message: "\(activity.title) is coming later. Go in calm and avoid turning the evening into extra stress.",
                focusActivity: activity
            )

        case .night:
            return makeCard(
                state: .sleep,
                title: "It’s late",
                action: "Choose wisely",
                message: "\(activity.title) is still on the plan, but it’s late. If you do it, keep it short and easy.",
                focusActivity: activity
            )
        }
    }

    private func completedEarlierMessage(
        for activity: PlannedActivity,
        sleepHours: Double,
        phase: CoachDayPhase
    ) -> WorkoutRecoveryCoachCard {

        let load = activityLoad(activity)

        if phase == .night {
            return makeCard(
                state: .sleep,
                title: "Recovery mode",
                action: "Let sleep work",
                message: "\(activity.title) is behind you. Keep the night calm so recovery can actually happen.",
                focusActivity: activity
            )
        }

        if load == .veryLongEndurance || load == .longEndurance {
            return makeCard(
                state: .recovery,
                title: "Still recovering",
                action: "Refuel again",
                message: "\(activity.title) was earlier, but recovery continues. Keep fluids and balanced food coming through the day.",
                focusActivity: activity
            )
        }

        if sleepHours > 0 && sleepHours < 6 {
            return makeCard(
                state: .recovery,
                title: "Don’t overstack",
                action: "Protect energy",
                message: "\(activity.title) is done, and sleep was short. Avoid adding more load unless it’s very easy.",
                focusActivity: activity
            )
        }

        switch phase {
        case .morning, .afternoon:
            return makeCard(
                state: .recovery,
                title: "Session done",
                action: "Keep it steady",
                message: "\(activity.title) is already done. Nice — keep the rest of the day smooth, not heavy.",
                focusActivity: activity
            )

        case .evening:
            return makeCard(
                state: .recovery,
                title: "Wind down well",
                action: "Let recovery start",
                message: "\(activity.title) is done. Let the evening be calmer now — that’s where recovery begins.",
                focusActivity: activity
            )

        case .night:
            return makeCard(
                state: .sleep,
                title: "Recovery mode",
                action: "Let sleep work",
                message: "\(activity.title) is behind you. Keep the night calm so recovery can actually happen.",
                focusActivity: activity
            )
        }
    }

    private func noWorkoutMessage(
        for phase: CoachDayPhase,
        activeCalories: Double
    ) -> WorkoutRecoveryCoachCard {

        if activeCalories > 650 {
            return makeCard(
                state: .recovery,
                title: "Active day",
                action: "Recover lightly",
                message: "No workout is planned, but your body has already done a lot today. Hydrate and keep the evening easy.",
                focusActivity: nil
            )
        }

        switch phase {
        case .morning:
            return makeCard(
                state: .movement,
                title: "Start easy",
                action: "Wake the body",
                message: "No workout is planned right now. A short walk or a few minutes of mobility is enough to start well.",
                focusActivity: nil
            )

        case .afternoon:
            return makeCard(
                state: .movement,
                title: "Small reset",
                action: "Move a little",
                message: "A short easy walk can reset the day without making it feel like another task.",
                focusActivity: nil
            )

        case .evening:
            return makeCard(
                state: .movement,
                title: "Keep it light",
                action: "Wind down gently",
                message: "Evening is better for easy movement than pushing hard. Keep it simple and calm.",
                focusActivity: nil
            )

        case .night:
            return makeCard(
                state: .sleep,
                title: "Recovery mode",
                action: "Let the body settle",
                message: "Your body is shifting into overnight recovery. The calmer the night, the better tomorrow feels.",
                focusActivity: nil
            )
        }
    }

    private func movementMessage(for phase: CoachDayPhase) -> WorkoutRecoveryCoachCard {

        switch phase {
        case .morning:
            return makeCard(
                state: .movement,
                title: "Build momentum",
                action: "Start with 10 min",
                message: "A light walk can help the day feel easier. Nothing serious — just get moving.",
                focusActivity: nil
            )

        case .afternoon:
            return makeCard(
                state: .movement,
                title: "Energy reset",
                action: "Step away",
                message: "A short walk can clear the head and bring energy back without stressing the body.",
                focusActivity: nil
            )

        case .evening:
            return makeCard(
                state: .movement,
                title: "Easy reset",
                action: "Keep it calm",
                message: "Use gentle movement to close the day, not to make up for anything.",
                focusActivity: nil
            )

        case .night:
            return makeCard(
                state: .sleep,
                title: "Rest comes first",
                action: "Choose recovery",
                message: "Late evenings are better for slowing down than chasing more activity. Let recovery work now.",
                focusActivity: nil
            )
        }
    }

    private func makeCard(
        state: WorkoutRecoveryCoachState,
        title: String,
        action: String,
        message: String,
        focusActivity: PlannedActivity?
    ) -> WorkoutRecoveryCoachCard {
        .init(
            state: state,
            title: limited(title, to: maxTitleCharacters),
            action: limited(action, to: maxActionCharacters),
            message: limited(message, to: maxMessageCharacters),
            focusActivity: focusActivity
        )
    }

    private func limited(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }

        let endIndex = text.index(text.startIndex, offsetBy: max(0, limit - 1))
        let trimmed = String(text[..<endIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmed + "…"
    }

    private func activityLoad(_ activity: PlannedActivity) -> ActivityLoad {
        let duration = activity.durationMinutes
        let text = "\(activity.type) \(activity.title)".lowercased()

        let isCycling = text.contains("cycling") || text.contains("bike")
        let isRun = text.contains("run") || text.contains("running")
        let isWalk = text.contains("walk")
        let isYoga = text.contains("yoga") || text.contains("mobility") || text.contains("stretch")
        let isStrength = text.contains("strength") || text.contains("gym") || text.contains("lift") || text.contains("weights")
        let isHighIntensity = text.contains("hiit") || text.contains("interval") || text.contains("cardio")

        if (isCycling || isRun) && duration >= 150 {
            return .veryLongEndurance
        }

        if (isCycling || isRun || isHighIntensity) && duration >= 75 {
            return .longEndurance
        }

        if isHighIntensity || ((isCycling || isRun) && duration >= 45) {
            return .highIntensity
        }

        if isStrength {
            return .strength
        }

        if isWalk || isYoga || duration <= 30 {
            return .light
        }

        return .moderate
    }

    private func dayPhase(_ date: Date) -> CoachDayPhase {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    private func liveActivity(
        from activities: [PlannedActivity],
        now: Date
    ) -> PlannedActivity? {
        activities.first {
            let end = activityEnd($0)

            return now >= $0.date
                && now <= end
                && !$0.isCompleted
                && !$0.isSkipped
        }
    }

    private func upcomingSoonActivity(
        from activities: [PlannedActivity],
        now: Date
    ) -> PlannedActivity? {
        activities
            .filter {
                let timeUntilStart = $0.date.timeIntervalSince(now)

                return !$0.isCompleted
                    && !$0.isSkipped
                    && timeUntilStart > 0
                    && timeUntilStart <= preActivityWindow
            }
            .sorted { $0.date < $1.date }
            .first
    }

    private func laterTodayActivity(
        from activities: [PlannedActivity],
        now: Date
    ) -> PlannedActivity? {
        activities
            .filter {
                !$0.isCompleted
                    && !$0.isSkipped
                    && $0.date > now
            }
            .sorted { $0.date < $1.date }
            .first
    }

    private func recentlyCompletedActivity(
        from activities: [PlannedActivity],
        now: Date
    ) -> PlannedActivity? {
        activities
            .filter {
                let timeSinceEnd = now.timeIntervalSince(activityEnd($0))

                return $0.isCompleted
                    && !$0.isSkipped
                    && timeSinceEnd >= 0
                    && timeSinceEnd <= recoveryWindow
            }
            .sorted { activityEnd($0) > activityEnd($1) }
            .first
    }

    private func completedEarlierActivity(
        from activities: [PlannedActivity],
        now: Date
    ) -> PlannedActivity? {
        activities
            .filter {
                let timeSinceEnd = now.timeIntervalSince(activityEnd($0))

                return $0.isCompleted
                    && !$0.isSkipped
                    && timeSinceEnd > recoveryWindow
            }
            .sorted { activityEnd($0) > activityEnd($1) }
            .first
    }

    private func recentlyMissedActivity(
        from activities: [PlannedActivity],
        now: Date
    ) -> PlannedActivity? {
        activities
            .filter {
                let timeSinceEnd = now.timeIntervalSince(activityEnd($0))

                return !$0.isCompleted
                    && !$0.isSkipped
                    && timeSinceEnd >= 0
                    && timeSinceEnd <= missedWindow
            }
            .sorted { activityEnd($0) > activityEnd($1) }
            .first
    }

    private func recentlySkippedActivity(
        from activities: [PlannedActivity],
        now: Date
    ) -> PlannedActivity? {
        activities
            .filter {
                let timeSinceEnd = now.timeIntervalSince(activityEnd($0))

                return $0.isSkipped
                    && timeSinceEnd >= 0
                    && timeSinceEnd <= missedWindow
            }
            .sorted { activityEnd($0) > activityEnd($1) }
            .first
    }

    private func activityEnd(_ activity: PlannedActivity) -> Date {
        activity.date.addingTimeInterval(TimeInterval(activity.durationMinutes * 60))
    }

    private func isPhysicalActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()

        return type.contains("activity")
            || type.contains("workout")
            || type.contains("training")
            || type.contains("run")
            || type.contains("walk")
            || type.contains("cardio")
            || type.contains("strength")
            || type.contains("cycling")
            || type.contains("bike")
            || type.contains("yoga")
            || title.contains("run")
            || title.contains("walk")
            || title.contains("workout")
            || title.contains("gym")
            || title.contains("cycling")
            || title.contains("bike")
            || title.contains("cardio")
            || title.contains("yoga")
            || title.contains("training")
            || title.contains("strength")
            || title.contains("hiit")
            || title.contains("mobility")
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private enum ActivityLoad {
    case light
    case moderate
    case strength
    case highIntensity
    case longEndurance
    case veryLongEndurance
}
