import Foundation

enum HistoricalActivityAggregator {

    static func aggregate(
        templates: [SimilarDayTemplate],
        todayWeekday: Int,
        calendar: Calendar = .current
    ) -> [HistoricalActivityAggregate] {
        var buckets: [String: Bucket] = [:]

        for template in templates {
            for activity in template.activities where !activity.isSkipped {
                let type = activity.type.lowercased()
                if type == "meal" || type == "snack" || type == "food" || type == "drink" || type == "water" {
                    continue
                }
                let signature = makeSignature(title: activity.title, type: activity.type)
                var bucket = buckets[signature] ?? Bucket(
                    signature: signature,
                    title: activity.title,
                    activityType: activity.type,
                    icon: activity.icon,
                    imageName: activity.imageName,
                    colorRed: activity.colorRed,
                    colorGreen: activity.colorGreen,
                    colorBlue: activity.colorBlue
                )
                bucket.occurrenceCount += 1
                if activity.isCompleted { bucket.completionCount += 1 }
                if activity.isPartialCompletion { bucket.partialCount += 1 }
                bucket.durations.append(max(15, activity.durationMinutes))
                let hour = calendar.component(.hour, from: activity.date)
                let minute = calendar.component(.minute, from: activity.date)
                bucket.hours.append(hour)
                bucket.minutes.append(minute)
                let weekday = calendar.component(.weekday, from: activity.date)
                if weekday == todayWeekday {
                    bucket.weekdayMatchCount += 1
                    bucket.weekdayHours.append(hour)
                    bucket.weekdayMinutes.append(minute)
                }
                if template.observationAvailable { bucket.observationBackedCount += 1 }
                buckets[signature] = bucket
            }

            for activity in template.activities where activity.isSkipped {
                let type = activity.type.lowercased()
                if type == "meal" || type == "snack" || type == "food" || type == "drink" || type == "water" {
                    continue
                }
                let signature = makeSignature(title: activity.title, type: activity.type)
                guard var bucket = buckets[signature] else { continue }
                bucket.skipCount += 1
                buckets[signature] = bucket
            }
        }

        return buckets.values.map { bucket in
            // Prefer the habitual clock from same-weekday occurrences when available.
            let habitualHour = median(bucket.weekdayHours.isEmpty ? bucket.hours : bucket.weekdayHours) ?? 12
            let habitualMinute = median(bucket.weekdayMinutes.isEmpty ? bucket.minutes : bucket.weekdayMinutes) ?? 0
            return HistoricalActivityAggregate(
                id: bucket.signature,
                signature: bucket.signature,
                title: bucket.title,
                activityType: bucket.activityType,
                icon: bucket.icon,
                imageName: bucket.imageName,
                colorRed: bucket.colorRed,
                colorGreen: bucket.colorGreen,
                colorBlue: bucket.colorBlue,
                medianDurationMinutes: median(bucket.durations) ?? 45,
                habitualHour: habitualHour,
                habitualMinute: habitualMinute,
                completionCount: bucket.completionCount,
                skipCount: bucket.skipCount,
                occurrenceCount: bucket.occurrenceCount,
                observationBackedCount: bucket.observationBackedCount,
                weekdayMatchCount: bucket.weekdayMatchCount
            )
        }
        .sorted { lhs, rhs in
            if lhs.completionCount != rhs.completionCount {
                return lhs.completionCount > rhs.completionCount
            }
            return lhs.signature < rhs.signature
        }
    }

    static func makeSignature(title: String, type: String) -> String {
        let normalizedTitle = title
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return "\(type.lowercased())|\(normalizedTitle)"
    }

    private struct Bucket {
        let signature: String
        let title: String
        let activityType: String
        let icon: String
        let imageName: String
        let colorRed: Double
        let colorGreen: Double
        let colorBlue: Double
        var completionCount = 0
        var skipCount = 0
        var partialCount = 0
        var occurrenceCount = 0
        var observationBackedCount = 0
        var weekdayMatchCount = 0
        var durations: [Int] = []
        var hours: [Int] = []
        var minutes: [Int] = []
        var weekdayHours: [Int] = []
        var weekdayMinutes: [Int] = []
    }

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
