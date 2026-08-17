import Foundation

/// Time-in-zone and average HR helpers that follow Apple Fitness more closely
/// than an unweighted mean of samples.
enum WorkoutHeartRateAnalytics {
    /// Gaps longer than this are treated as lost signal, not extra time in the last zone.
    static let maximumSampleInterval: TimeInterval = 180

    static func secondsInZone(
        samples: [WorkoutHeartRateSample],
        activeIntervals: [DateInterval],
        contains: (Double) -> Bool
    ) -> TimeInterval {
        guard !activeIntervals.isEmpty else { return 0 }

        return activeIntervals.reduce(0) { total, interval in
            total + secondsInZone(
                samples: samples,
                startDate: interval.start,
                endDate: interval.end,
                contains: contains
            )
        }
    }

    static func secondsInZone(
        samples: [WorkoutHeartRateSample],
        startDate: Date,
        endDate: Date,
        contains: (Double) -> Bool
    ) -> TimeInterval {
        let clipped = samples.filter {
            $0.timestamp >= startDate && $0.timestamp <= endDate
        }
        guard clipped.count > 1 else { return 0 }

        return zip(clipped, clipped.dropFirst()).reduce(0.0) { total, pair in
            guard contains(pair.0.beatsPerMinute) else { return total }

            let intervalStart = max(pair.0.timestamp, startDate)
            let intervalEnd = min(pair.1.timestamp, endDate)
            let interval = intervalEnd.timeIntervalSince(intervalStart)

            return total + max(0, min(interval, maximumSampleInterval))
        }
    }

    static func samples(
        _ samples: [WorkoutHeartRateSample],
        in intervals: [DateInterval]
    ) -> [WorkoutHeartRateSample] {
        guard !intervals.isEmpty else { return samples }

        return samples.filter { sample in
            intervals.contains { interval in
                sample.timestamp >= interval.start && sample.timestamp <= interval.end
            }
        }
    }

    static func merging(
        _ lhs: [WorkoutHeartRateSample],
        _ rhs: [WorkoutHeartRateSample]
    ) -> [WorkoutHeartRateSample] {
        var byTimestamp: [TimeInterval: WorkoutHeartRateSample] = [:]

        for sample in lhs + rhs {
            let key = (sample.timestamp.timeIntervalSince1970 * 2).rounded() / 2
            if byTimestamp[key] == nil {
                byTimestamp[key] = sample
            }
        }

        return byTimestamp.values.sorted { $0.timestamp < $1.timestamp }
    }

    static func timeWeightedAverage(
        samples: [WorkoutHeartRateSample]
    ) -> Double? {
        guard let first = samples.first else { return nil }
        guard samples.count > 1 else { return first.beatsPerMinute }

        var weighted = 0.0
        var duration = 0.0

        for (current, next) in zip(samples, samples.dropFirst()) {
            let interval = min(
                max(next.timestamp.timeIntervalSince(current.timestamp), 0),
                maximumSampleInterval
            )
            weighted += current.beatsPerMinute * interval
            duration += interval
        }

        guard duration > 0 else {
            return samples.map(\.beatsPerMinute).reduce(0, +) / Double(samples.count)
        }

        return weighted / duration
    }

    /// Apple Fitness uses `h:mm:ss` once a zone exceeds an hour, otherwise `mm:ss`.
    static func durationLabel(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%02d:%02d", minutes, secs)
    }
}
