import Foundation
import SwiftUI

/// Shared heart-rate zone model — post-workout charts and live coaching use the same bands.
enum HeartRateZones {
    struct Definition: Equatable, Sendable {
        let number: Int
        let lowerBound: Double
        let upperBound: Double

        var bpmRangeLabel: String {
            if number >= 5 {
                return "\(Int(lowerBound))+"
            }
            return "\(Int(lowerBound))–\(Int(upperBound - 1))"
        }

        func contains(_ beatsPerMinute: Double) -> Bool {
            beatsPerMinute >= lowerBound && beatsPerMinute < upperBound
        }
    }

    /// Absolute BPM bands (same cutovers as ActivityIntelligence zone chart).
    static let definitions: [Definition] = [
        Definition(number: 1, lowerBound: 40, upperBound: 120),
        Definition(number: 2, lowerBound: 120, upperBound: 140),
        Definition(number: 3, lowerBound: 140, upperBound: 160),
        Definition(number: 4, lowerBound: 160, upperBound: 180),
        Definition(number: 5, lowerBound: 180, upperBound: 220)
    ]

    static func definition(for zone: Int) -> Definition {
        definitions.first { $0.number == zone } ?? definitions[0]
    }

    static func zone(for beatsPerMinute: Double) -> Int {
        definitions.first { $0.contains(beatsPerMinute) }?.number
            ?? definitions.last!.number
    }

    static func zone(forBPM bpm: Int) -> Int {
        zone(for: Double(bpm))
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

    /// Compact badge: "Zone 4 · 162" / "Зона 4 · 162"
    static func badgeLabel(zone: Int, bpm: Int) -> String {
        "\(localizedTitle(for: zone)) · \(bpm)"
    }

    static func color(for zone: Int) -> Color {
        switch zone {
        case 1: return Color(red: 0.30, green: 0.72, blue: 0.95) // blue
        case 2: return Color(red: 0.45, green: 0.78, blue: 0.45) // green
        case 3: return Color(red: 0.96, green: 0.86, blue: 0.20) // yellow
        case 4: return Color(red: 0.96, green: 0.54, blue: 0.16) // orange
        default: return Color(red: 0.96, green: 0.42, blue: 0.42) // red
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
}
