import CoreLocation
import Foundation

/// Peak speed from GPS route points with spike rejection.
///
/// Raw consecutive `max()` picks GPS jumps (e.g. 75 km/h). Over-filtering
/// (long min interval on 1 Hz routes) can leave only slow pause segments and
/// report a “max” below average — also wrong. This calculator:
/// 1) uses short valid segments from dense GPS,
/// 2) drops speeds above a sport / average-based ceiling,
/// 3) never returns a peak below average speed when average is known.
public enum WorkoutRouteMaxSpeedCalculator {
    public static let minimumIntervalSeconds: TimeInterval = 1.0
    public static let maximumIntervalSeconds: TimeInterval = 45
    public static let minimumSegmentMeters: Double = 2

    public enum AbsoluteCeilingKmh {
        public static let walking = 12.0
        public static let hiking = 18.0
        public static let running = 42.0
        public static let cycling = 65.0
        public static let swimming = 9.0
        public static let outdoorDefault = 70.0
    }

    public static func maxSpeedKmh(
        from points: [WorkoutRoutePoint],
        averageSpeedKmh: Double? = nil,
        absoluteCeilingKmh: Double = AbsoluteCeilingKmh.outdoorDefault
    ) -> Double? {
        let spikeCeiling = spikeCeilingKmh(
            averageSpeedKmh: averageSpeedKmh,
            absoluteCeilingKmh: absoluteCeilingKmh
        )

        let speeds = segmentSpeedsKmh(from: points)
            .filter { $0 <= spikeCeiling }

        let routePeak = speeds.max()

        switch (routePeak, averageSpeedKmh) {
        case let (peak?, average?) where average > 0:
            // Max cannot be below average (distance/duration).
            return min(max(peak, average), absoluteCeilingKmh)
        case let (peak?, _):
            return min(peak, absoluteCeilingKmh)
        case (nil, let average?) where average > 0:
            // Route unusable — fall back to average rather than inventing a lower max.
            return min(average, absoluteCeilingKmh)
        default:
            return nil
        }
    }

    public static func segmentSpeedsKmh(from points: [WorkoutRoutePoint]) -> [Double] {
        guard points.count > 1 else { return [] }

        return zip(points, points.dropFirst()).compactMap { start, end in
            let interval = end.timestamp.timeIntervalSince(start.timestamp)
            guard interval >= minimumIntervalSeconds, interval <= maximumIntervalSeconds else {
                return nil
            }

            let distance = CLLocation(
                latitude: start.latitude,
                longitude: start.longitude
            ).distance(
                from: CLLocation(latitude: end.latitude, longitude: end.longitude)
            )
            guard distance >= minimumSegmentMeters else { return nil }

            let speed = distance / interval * 3.6
            guard speed.isFinite, speed > 0.5 else { return nil }
            return speed
        }
    }

    /// Reject GPS teleport spikes while keeping legitimate surges above average.
    private static func spikeCeilingKmh(
        averageSpeedKmh: Double?,
        absoluteCeilingKmh: Double
    ) -> Double {
        guard let averageSpeedKmh, averageSpeedKmh > 0 else {
            return absoluteCeilingKmh
        }
        // Casual ride ~15 km/h → ceiling ~45; rejects 75 km/h jumps.
        let relative = max(averageSpeedKmh * 3.0, averageSpeedKmh + 22)
        return min(absoluteCeilingKmh, relative)
    }
}
