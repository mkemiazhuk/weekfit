import Foundation
import SwiftUI

/// Heart-rate zones matching Apple Fitness / Activity automatic bands.
///
/// Apple Watch uses heart-rate reserve (Karvonen) against `maxHR = 220 − age`:
/// Zone 1 below 60% HRR, Zone 2 60–70%, Zone 3 70–80%, Zone 4 80–90%, Zone 5 90%+.
enum HeartRateZones {
    struct Profile: Equatable, Sendable {
        let maxHeartRate: Double
        let restingHeartRate: Double

        var reserve: Double { max(maxHeartRate - restingHeartRate, 40) }

        /// Apple Fitness automatic max HR estimate (`220 − age`).
        static func appleEstimatedMaxHeartRate(age: Int) -> Double {
            let clampedAge = min(max(age, 10), 90)
            return 220 - Double(clampedAge)
        }

        static func apple(age: Int, restingHeartRate: Double) -> Profile {
            let resting = restingHeartRate >= 40 && restingHeartRate <= 110
                ? restingHeartRate
                : 60
            // Age 0 falls back to max 190 → Zone 1 `< 138`. Apple Fitness for a
            // 40-year-old is `< 132` (`220 − 40`). Prefer a real HealthKit age.
            let maxHR: Double
            if age > 0 {
                maxHR = appleEstimatedMaxHeartRate(age: age)
            } else {
                maxHR = 190
            }
            return Profile(
                maxHeartRate: max(maxHR, resting + 40),
                restingHeartRate: resting
            )
        }

        static let fallback = Profile.apple(age: 0, restingHeartRate: 60)
    }

    struct Definition: Equatable, Sendable {
        let number: Int
        let lowerBound: Double
        let upperBound: Double

        var bpmRangeLabel: String {
            HeartRateZones.bpmRangeLabel(for: number, lowerBound: lowerBound, upperBound: upperBound)
        }

        func contains(_ beatsPerMinute: Double) -> Bool {
            beatsPerMinute >= lowerBound && beatsPerMinute < upperBound
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var storedProfile = Profile.fallback

    static var currentProfile: Profile {
        lock.lock()
        defer { lock.unlock() }
        return storedProfile
    }

    static func updatePhysiology(age: Int, restingHeartRate: Double) {
        let profile = Profile.apple(age: age, restingHeartRate: restingHeartRate)
        lock.lock()
        storedProfile = profile
        lock.unlock()
    }

    static var definitions: [Definition] {
        definitions(for: currentProfile)
    }

    static func definitions(for profile: Profile) -> [Definition] {
        // Exclusive uppers chosen so Fitness-style labels stay contiguous:
        // `< 132`, `133–144`, `145–155`, `156–167`, `168+`.
        let lastEasy = threshold(fraction: 0.60, profile: profile)
        let lastAerobic = threshold(fraction: 0.70, profile: profile)
        let tempoStart = threshold(fraction: 0.80, profile: profile)
        let maxStart = threshold(fraction: 0.90, profile: profile)

        let z1Upper = lastEasy + 1
        let z2Upper = max(lastAerobic + 1, z1Upper + 1)
        let z3Upper = max(tempoStart, z2Upper + 1)
        let z4Upper = max(maxStart, z3Upper + 1)

        return [
            Definition(number: 1, lowerBound: 40, upperBound: z1Upper),
            Definition(number: 2, lowerBound: z1Upper, upperBound: z2Upper),
            Definition(number: 3, lowerBound: z2Upper, upperBound: z3Upper),
            Definition(number: 4, lowerBound: z3Upper, upperBound: z4Upper),
            Definition(number: 5, lowerBound: z4Upper, upperBound: 220)
        ]
    }

    static func definition(for zone: Int, profile: Profile = currentProfile) -> Definition {
        definitions(for: profile).first { $0.number == zone } ?? definitions(for: profile)[0]
    }

    static func zone(for beatsPerMinute: Double, profile: Profile = currentProfile) -> Int {
        definitions(for: profile).first { $0.contains(beatsPerMinute) }?.number
            ?? 5
    }

    static func zone(forBPM bpm: Int, profile: Profile = currentProfile) -> Int {
        zone(for: Double(bpm), profile: profile)
    }

    static func isElevated(_ zone: Int) -> Bool { zone >= 4 }
    static func isCritical(_ zone: Int) -> Bool { zone >= 5 }

    // MARK: - Display

    static func localizedTitle(for zone: Int) -> String {
        WeekFitLocalizedString("activity.heartRate.zone\(max(1, min(5, zone)))")
    }

    static func localizedEffort(for zone: Int) -> String {
        WeekFitLocalizedString("coach.heartRate.zone\(max(1, min(5, zone))).effort")
    }

    /// Compact badge: "Zone 4" / "Зона 4" — zone only, no live BPM.
    static func badgeLabel(zone: Int) -> String {
        localizedTitle(for: zone)
    }

    static func bpmRangeLabel(for zone: Int, profile: Profile = currentProfile) -> String {
        let definition = definition(for: zone, profile: profile)
        return bpmRangeLabel(
            for: definition.number,
            lowerBound: definition.lowerBound,
            upperBound: definition.upperBound
        )
    }

    /// Apple Fitness zone colors: light blue → teal → lime → orange → magenta.
    static func color(for zone: Int) -> Color {
        switch zone {
        case 1: return Color(red: 0.39, green: 0.82, blue: 1.00)
        case 2: return Color(red: 0.22, green: 0.84, blue: 0.80)
        case 3: return Color(red: 0.73, green: 0.92, blue: 0.20)
        case 4: return Color(red: 1.00, green: 0.62, blue: 0.08)
        default: return Color(red: 1.00, green: 0.27, blue: 0.55)
        }
    }

    static func semanticColor(for zone: Int) -> CoachSemanticColor {
        switch zone {
        case 1: return .liveZone1
        case 2: return .liveZone2
        case 3: return .liveZone3
        case 4: return .liveElevated
        default: return .liveCritical
        }
    }

    static func isLiveZoneColor(_ color: CoachSemanticColor) -> Bool {
        switch color {
        case .liveZone1, .liveZone2, .liveZone3, .liveElevated, .liveCritical:
            return true
        default:
            return false
        }
    }

    // MARK: - Private

    private static func threshold(fraction: Double, profile: Profile) -> Double {
        (profile.restingHeartRate + profile.reserve * fraction).rounded()
    }

    private static func bpmRangeLabel(
        for zone: Int,
        lowerBound: Double,
        upperBound: Double
    ) -> String {
        if zone <= 1 {
            return String(
                format: WeekFitLocalizedString("common.unit.bpmLessThanFormat"),
                max(Int(upperBound) - 1, 0)
            )
        }
        if zone >= 5 {
            return String(
                format: WeekFitLocalizedString("common.unit.bpmPlusFormat"),
                Int(lowerBound)
            )
        }
        return String(
            format: WeekFitLocalizedString("common.unit.bpmRangeFormat"),
            Int(lowerBound),
            Int(upperBound - 1)
        )
    }
}
