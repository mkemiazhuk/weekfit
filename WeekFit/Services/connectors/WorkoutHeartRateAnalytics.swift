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
        let active = coalesce(activeIntervals)
        guard !active.isEmpty else { return 0 }

        // Single pass over sample gaps against the coalesced active timeline.
        // Summing per raw interval double-counts when HKWorkout activities overlap.
        guard samples.count > 1 else { return 0 }

        return zip(samples, samples.dropFirst()).reduce(0.0) { total, pair in
            guard contains(pair.0.beatsPerMinute) else { return total }

            let gapStart = pair.0.timestamp
            let rawGap = pair.1.timestamp.timeIntervalSince(gapStart)
            guard rawGap > 0 else { return total }

            let gapEnd = gapStart.addingTimeInterval(min(rawGap, maximumSampleInterval))
            return total + activeOverlapDuration(from: gapStart, to: gapEnd, in: active)
        }
    }

    static func secondsInZone(
        samples: [WorkoutHeartRateSample],
        startDate: Date,
        endDate: Date,
        contains: (Double) -> Bool
    ) -> TimeInterval {
        secondsInZone(
            samples: samples,
            activeIntervals: [DateInterval(start: startDate, end: endDate)],
            contains: contains
        )
    }

    /// Merges overlapping / touching intervals so zone time cannot exceed wall-clock coverage.
    static func coalesce(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }

        guard var current = sorted.first else { return [] }

        var result: [DateInterval] = []
        for next in sorted.dropFirst() {
            if next.start <= current.end {
                current = DateInterval(
                    start: current.start,
                    end: max(current.end, next.end)
                )
            } else {
                result.append(current)
                current = next
            }
        }
        result.append(current)
        return result
    }

    private static func activeOverlapDuration(
        from start: Date,
        to end: Date,
        in intervals: [DateInterval]
    ) -> TimeInterval {
        guard end > start else { return 0 }

        return intervals.reduce(0) { total, interval in
            let overlapStart = max(start, interval.start)
            let overlapEnd = min(end, interval.end)
            return total + max(0, overlapEnd.timeIntervalSince(overlapStart))
        }
    }

    static func samples(
        _ samples: [WorkoutHeartRateSample],
        in intervals: [DateInterval]
    ) -> [WorkoutHeartRateSample] {
        let active = coalesce(intervals)
        guard !active.isEmpty else { return samples }

        return samples.filter { sample in
            active.contains { interval in
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
