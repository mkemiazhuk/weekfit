import Foundation

/// Defaults for the add-activity sheet so a repeat plan needs fewer taps.
enum PlanAddPreference {

    /// Chip order when nothing has been planned yet.
    static let typeOrder: [PlannerType] = [.recovery, .workout, .meal, .habit]
    /// How far back the default type and activity are counted. Not just today.
    static let lookbackDays = 30

    struct Sample: Equatable {
        let type: PlannerType
        let title: String
        let imageName: String
        let minuteOfDay: Int
        let durationMinutes: Int
    }

    struct Habit: Equatable {
        let minuteOfDay: Int
        let durationMinutes: Int
    }

    static func samples(
        from activities: [PlannedActivity],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Sample] {
        let todayStart = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -lookbackDays, to: todayStart) ?? todayStart
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        return activities.compactMap { activity in
            guard activity.date >= windowStart, activity.date < windowEnd else { return nil }
            guard !activity.isSkipped else { return nil }
            guard let type = plannerType(
                storedType: activity.type,
                title: activity.title,
                imageName: activity.imageName
            ) else { return nil }

            let hour = calendar.component(.hour, from: activity.date)
            let minute = calendar.component(.minute, from: activity.date)
            return Sample(
                type: type,
                title: activity.title,
                imageName: activity.imageName,
                minuteOfDay: hour * 60 + minute,
                durationMinutes: max(activity.durationMinutes, 1)
            )
        }
    }

    /// Most-used type. Ties follow ``typeOrder``. No history starts on Recovery.
    static func preferredType(_ samples: [Sample]) -> PlannerType {
        let counts = Dictionary(grouping: samples, by: \.type).mapValues(\.count)
        return typeOrder.max { lhs, rhs in
            let left = counts[lhs, default: 0]
            let right = counts[rhs, default: 0]
            if left != right { return left < right }
            return orderIndex(lhs) > orderIndex(rhs)
        } ?? .recovery
    }

    static func rankedOptions(
        _ options: [PlannerOption],
        type: PlannerType,
        samples: [Sample]
    ) -> [PlannerOption] {
        ranked(options, type: type, samples: samples, title: \.title, imageName: \.imageName)
    }

    static func rankedMeals(_ meals: [Meals], samples: [Sample]) -> [Meals] {
        ranked(meals, type: .meal, samples: samples, title: \.title, imageName: \.imageName)
    }

    /// Usual clock and length for this exact activity. Nil when it has never been planned.
    static func habit(
        type: PlannerType,
        title: String,
        imageName: String,
        samples: [Sample]
    ) -> Habit? {
        let matches = matching(samples, type: type, title: title, imageName: imageName)
        guard !matches.isEmpty,
              let minute = median(matches.map(\.minuteOfDay)),
              let duration = median(matches.map(\.durationMinutes)) else {
            return nil
        }
        return Habit(
            minuteOfDay: roundedQuarter(minute),
            durationMinutes: max(duration, 15)
        )
    }

    /// Maps a stored plan row onto the four add-sheet types.
    static func plannerType(storedType: String, title: String, imageName: String) -> PlannerType? {
        let type = storedType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let image = imageName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if type == "meal" || type == "food" || type == "nutrition" { return .meal }
        if type == "workout" || type == "training" || image.hasPrefix("workout-") { return .workout }
        if type == "recovery" || type == "sauna" || image.hasPrefix("recovery-") { return .recovery }
        if type == "habit" || image.hasPrefix("habit-") { return .habit }

        for planner in typeOrder {
            if !image.isEmpty, planner.options.contains(where: {
                $0.imageName.lowercased() == image
            }) {
                return planner
            }
            if !name.isEmpty, planner.options.contains(where: {
                $0.title.lowercased() == name
            }) {
                return planner
            }
        }
        return nil
    }

    static func roundedQuarter(_ minuteOfDay: Int) -> Int {
        let rounded = Int((Double(minuteOfDay) / 15.0).rounded()) * 15
        return min(max(rounded, 5 * 60), 24 * 60)
    }

    private static func ranked<T>(
        _ items: [T],
        type: PlannerType,
        samples: [Sample],
        title: (T) -> String,
        imageName: (T) -> String
    ) -> [T] {
        items.enumerated()
            .sorted { lhs, rhs in
                let left = matching(
                    samples,
                    type: type,
                    title: title(lhs.element),
                    imageName: imageName(lhs.element)
                ).count
                let right = matching(
                    samples,
                    type: type,
                    title: title(rhs.element),
                    imageName: imageName(rhs.element)
                ).count
                if left != right { return left > right }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func matching(
        _ samples: [Sample],
        type: PlannerType,
        title: String,
        imageName: String
    ) -> [Sample] {
        let titleKey = normalized(title)
        return samples.filter { sample in
            guard sample.type == type else { return false }
            if !titleKey.isEmpty, normalized(sample.title) == titleKey { return true }
            if !imageName.isEmpty, sample.imageName == imageName { return true }
            return false
        }
    }

    private static func normalized(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func orderIndex(_ type: PlannerType) -> Int {
        typeOrder.firstIndex(of: type) ?? 0
    }

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
