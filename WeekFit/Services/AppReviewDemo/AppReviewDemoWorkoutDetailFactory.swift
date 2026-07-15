import Foundation
import HealthKit
import CoreLocation
import SwiftUI
import WeekFitWorkoutMetrics

/// Builds Watch-quality activity detail payloads for App Review demo sessions.
enum AppReviewDemoWorkoutDetailFactory {

    static func stableWorkoutID(title: String, date: Date) -> UUID {
        let day = Int(date.timeIntervalSince1970 / 86_400)
        let seed = "\(title.lowercased())|\(day)"
        var hash: UInt64 = 5_381
        for byte in seed.utf8 {
            hash = 1_099_511_628_211 &* hash &+ UInt64(byte)
        }

        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<16 {
            let shift = (index % 8) * 8
            bytes[index] = UInt8((hash >> shift) & 0xFF) ^ UInt8((index * 17) & 0xFF)
        }

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    static func makeDetail(
        title: String,
        activityType: HKWorkoutActivityType,
        startDate: Date,
        durationMinutes: Int,
        calories: Int,
        icon: String,
        color: Color
    ) -> ActivitySessionDetailSnapshot {
        let minutes = max(1, durationMinutes)
        let endDate = Calendar.current.date(byAdding: .minute, value: minutes, to: startDate) ?? startDate
        let durationSeconds = TimeInterval(minutes * 60)
        let profile = intensityProfile(for: activityType, title: title)
        let distanceKm = profile.distanceKm(forMinutes: minutes)
        let samples = heartRateSamples(
            start: startDate,
            durationSeconds: durationSeconds,
            averageBPM: profile.averageHR,
            maxBPM: profile.maxHR
        )
        let route = profile.includesRoute
            ? routePoints(
                start: startDate,
                durationSeconds: durationSeconds,
                distanceKm: distanceKm ?? 2.0,
                seed: title
            )
            : []
        let heartRates = samples.map(\.beatsPerMinute)
        let averageHR = heartRates.isEmpty
            ? profile.averageHR
            : heartRates.reduce(0, +) / Double(heartRates.count)
        let peakHR = heartRates.max() ?? profile.maxHR

        return ActivitySessionDetailSnapshot(
            title: title,
            activityType: activityType,
            startDate: startDate,
            endDate: endDate,
            durationMinutes: minutes,
            workoutDurationSeconds: durationSeconds,
            elapsedDurationSeconds: endDate.timeIntervalSince(startDate),
            source: "Apple Watch",
            icon: icon,
            color: color,
            activeCalories: calories > 0 ? Double(calories) : Double(minutes * profile.caloriesPerMinute),
            distanceKm: distanceKm,
            averageHeartRate: averageHR,
            maxHeartRate: peakHR,
            heartRateSamples: samples,
            routePoints: route,
            elevationGain: profile.elevationGain(forDistanceKm: distanceKm ?? 0),
            steps: profile.steps(forMinutes: minutes, distanceKm: distanceKm),
            cadence: profile.cadence
        )
    }

    // MARK: - Profiles

    private struct IntensityProfile {
        let averageHR: Double
        let maxHR: Double
        let includesRoute: Bool
        let caloriesPerMinute: Int
        let kmPerHour: Double?
        let cadence: Double?
        let stepsPerMinute: Double?

        func distanceKm(forMinutes minutes: Int) -> Double? {
            guard let kmPerHour else { return nil }
            return ((Double(minutes) / 60.0) * kmPerHour * 100).rounded() / 100
        }

        func elevationGain(forDistanceKm distance: Double) -> Double? {
            guard includesRoute, distance > 0 else { return nil }
            return max(2, (distance * 8).rounded())
        }

        func steps(forMinutes minutes: Int, distanceKm: Double?) -> Int? {
            if let stepsPerMinute {
                return Int((Double(minutes) * stepsPerMinute).rounded())
            }
            guard let distanceKm else { return nil }
            return Int((distanceKm * 1_300).rounded())
        }
    }

    private static func intensityProfile(
        for activityType: HKWorkoutActivityType,
        title: String
    ) -> IntensityProfile {
        let lowered = title.lowercased()

        switch activityType {
        case .running:
            let interval = lowered.contains("interval") || lowered.contains("tempo")
            return IntensityProfile(
                averageHR: interval ? 156 : 142,
                maxHR: interval ? 178 : 164,
                includesRoute: true,
                caloriesPerMinute: interval ? 11 : 9,
                kmPerHour: interval ? 11.5 : 9.4,
                cadence: nil,
                stepsPerMinute: interval ? 175 : 165
            )
        case .walking:
            return IntensityProfile(
                averageHR: 99,
                maxHR: 110,
                includesRoute: true,
                caloriesPerMinute: 5,
                kmPerHour: 5.4,
                cadence: nil,
                stepsPerMinute: 110
            )
        case .hiking:
            return IntensityProfile(
                averageHR: 118,
                maxHR: 142,
                includesRoute: true,
                caloriesPerMinute: 7,
                kmPerHour: 4.2,
                cadence: nil,
                stepsPerMinute: 95
            )
        case .cycling:
            return IntensityProfile(
                averageHR: 132,
                maxHR: 158,
                includesRoute: true,
                caloriesPerMinute: 9,
                kmPerHour: 22,
                cadence: 82,
                stepsPerMinute: nil
            )
        case .tennis:
            return IntensityProfile(
                averageHR: 138,
                maxHR: 168,
                includesRoute: false,
                caloriesPerMinute: 8,
                kmPerHour: nil,
                cadence: nil,
                stepsPerMinute: 70
            )
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return IntensityProfile(
                averageHR: 118,
                maxHR: 148,
                includesRoute: false,
                caloriesPerMinute: 7,
                kmPerHour: nil,
                cadence: nil,
                stepsPerMinute: 20
            )
        case .yoga, .mindAndBody:
            return IntensityProfile(
                averageHR: 88,
                maxHR: 104,
                includesRoute: false,
                caloriesPerMinute: 4,
                kmPerHour: nil,
                cadence: nil,
                stepsPerMinute: 10
            )
        default:
            return IntensityProfile(
                averageHR: 120,
                maxHR: 145,
                includesRoute: false,
                caloriesPerMinute: 6,
                kmPerHour: nil,
                cadence: nil,
                stepsPerMinute: 40
            )
        }
    }

    // MARK: - Synthetic samples

    private static func heartRateSamples(
        start: Date,
        durationSeconds: TimeInterval,
        averageBPM: Double,
        maxBPM: Double
    ) -> [WorkoutHeartRateSample] {
        let step: TimeInterval = 20
        let sampleCount = Swift.max(2, Int(durationSeconds / step))
        var samples: [WorkoutHeartRateSample] = []

        for index in 0..<sampleCount {
            let progress = Double(index) / Double(Swift.max(sampleCount - 1, 1))
            let warmup = min(1, progress / 0.12)
            let cooldown = progress > 0.85 ? Swift.max(0.55, 1 - (progress - 0.85) / 0.15) : 1
            let wave = sin(progress * .pi * 4.0) * 4.5
            let bpm = min(
                max(
                    (averageBPM - 8) + (maxBPM - averageBPM + 8) * warmup * cooldown + wave,
                    70
                ),
                190
            )

            samples.append(
                WorkoutHeartRateSample(
                    timestamp: start.addingTimeInterval(Double(index) * step),
                    beatsPerMinute: bpm.rounded()
                )
            )
        }

        return samples
    }

    private static func routePoints(
        start: Date,
        durationSeconds: TimeInterval,
        distanceKm: Double,
        seed: String
    ) -> [WorkoutRoutePoint] {
        let originLat = 52.2297
        let originLon = 21.0122
        let pointCount = Swift.max(40, min(120, Int(distanceKm * 45)))
        let meters = distanceKm * 1_000
        let metersPerPoint = meters / Double(Swift.max(pointCount - 1, 1))
        let headingSeed = Double(seed.utf8.reduce(0) { $0 &+ Int($1) } % 360) * .pi / 180

        var points: [WorkoutRoutePoint] = []
        var latitude = originLat
        var longitude = originLon
        var heading = headingSeed

        for index in 0..<pointCount {
            let progress = Double(index) / Double(Swift.max(pointCount - 1, 1))
            heading += sin(progress * .pi * 3) * 0.18

            let north = cos(heading) * metersPerPoint
            let east = sin(heading) * metersPerPoint
            latitude += north / 111_320
            longitude += east / (111_320 * cos(latitude * .pi / 180))

            let timestamp = start.addingTimeInterval(durationSeconds * progress)
            points.append(
                WorkoutRoutePoint(
                    latitude: latitude,
                    longitude: longitude,
                    altitude: 110 + sin(progress * .pi * 2) * 4,
                    verticalAccuracy: 3,
                    timestamp: timestamp
                )
            )
        }

        return points
    }
}
