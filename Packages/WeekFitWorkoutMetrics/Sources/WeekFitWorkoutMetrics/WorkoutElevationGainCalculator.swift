import Foundation

public enum WorkoutElevationGainCalculator {
    public static let minimumClimbMeters = 2.5
    public static let smoothingWindow = 5
    public static let maximumVerticalAccuracyMeters = 25.0

    public static func calculate(from points: [WorkoutRoutePoint]) -> Double? {
        guard points.count > 1 else { return nil }

        let smoothed = smoothedAltitudes(from: points)
        guard let firstReliable = smoothed.first(where: \.isReliable) else { return nil }

        var gain = 0.0
        var valley = firstReliable.altitude

        for sample in smoothed.dropFirst() where sample.isReliable {
            let altitude = sample.altitude

            if altitude - valley >= minimumClimbMeters {
                gain += altitude - valley
                valley = altitude
            } else if altitude < valley {
                valley = altitude
            }
        }

        return gain > 0 ? gain : nil
    }

    private struct AltitudeSample {
        let altitude: Double
        let isReliable: Bool
    }

    private static func smoothedAltitudes(from points: [WorkoutRoutePoint]) -> [AltitudeSample] {
        let raw = points.map {
            AltitudeSample(
                altitude: $0.altitude,
                isReliable: isAltitudeReliable($0)
            )
        }

        let halfWindow = smoothingWindow / 2

        return raw.enumerated().map { index, sample in
            guard sample.isReliable else {
                return AltitudeSample(altitude: sample.altitude, isReliable: false)
            }

            let lower = max(0, index - halfWindow)
            let upper = min(raw.count - 1, index + halfWindow)
            let reliableSlice = raw[lower...upper].filter(\.isReliable)
            guard !reliableSlice.isEmpty else {
                return AltitudeSample(altitude: sample.altitude, isReliable: false)
            }

            let average = reliableSlice.map(\.altitude).reduce(0, +) / Double(reliableSlice.count)
            return AltitudeSample(altitude: average, isReliable: true)
        }
    }

    private static func isAltitudeReliable(_ point: WorkoutRoutePoint) -> Bool {
        guard let accuracy = point.verticalAccuracy else {
            return true
        }

        return accuracy >= 0 && accuracy <= maximumVerticalAccuracyMeters
    }
}
