import Foundation

/// Determines how strongly Night Comfort should soften UI tokens (0 = vivid day, 1 = full comfort).
enum NightComfortWindowPolicy {

    static let rampInBeforeSunset: TimeInterval = 30 * 60
    static let rampInAfterSunset: TimeInterval = 90 * 60
    static let rampOutBeforeSunrise: TimeInterval = 45 * 60
    static let rampOutAfterSunrise: TimeInterval = 30 * 60

    static let fallbackStartHour = 20
    static let fallbackEndHour = 7
    static let fallbackRampDuration: TimeInterval = 45 * 60
    static let fallbackMorningRampDuration: TimeInterval = 30 * 60

    struct Input: Equatable, Sendable {
        var now: Date
        var sunset: Date?
        var sunrise: Date?
        var calendar: Calendar
        var preference: NightComfortPreference
    }

    static func blendFactor(_ input: Input) -> CGFloat {
        switch input.preference {
        case .off:
            return 0
        case .alwaysOn:
            return 1
        case .automatic:
            #if DEBUG
            if let override = NightComfortDebugSettings.blendOverride {
                return override
            }
            #endif
            if let sunset = input.sunset {
                return solarBlend(now: input.now, sunset: sunset, sunrise: input.sunrise, calendar: input.calendar)
            }
            return fallbackBlend(now: input.now, calendar: input.calendar)
        }
    }

    /// Next time the blend factor may change — used to schedule lightweight refresh timers.
    static func nextTransition(after now: Date, input: Input) -> Date? {
        let boundaries = transitionBoundaries(for: input)
        return boundaries
            .filter { $0 > now }
            .min()
    }

    // MARK: - Solar path

    private static func solarBlend(
        now: Date,
        sunset: Date,
        sunrise: Date?,
        calendar: Calendar
    ) -> CGFloat {
        let rampInStart = sunset.addingTimeInterval(-rampInBeforeSunset)
        let rampInEnd = sunset.addingTimeInterval(rampInAfterSunset)

        guard let sunrise else {
            if now < rampInStart { return 0 }
            if now <= rampInEnd { return linearRamp(now: now, start: rampInStart, end: rampInEnd) }
            return 1
        }

        let rampOutStart = sunrise.addingTimeInterval(-rampOutBeforeSunrise)
        let rampOutEnd = sunrise.addingTimeInterval(rampOutAfterSunrise)

        if now >= rampOutStart, now <= rampOutEnd {
            return 1 - linearRamp(now: now, start: rampOutStart, end: rampOutEnd)
        }

        if now >= rampInStart, now <= rampInEnd {
            return linearRamp(now: now, start: rampInStart, end: rampInEnd)
        }

        if now > rampInEnd || now < rampOutStart {
            return 1
        }

        return 0
    }

    // MARK: - Fallback path

    private static func fallbackBlend(now: Date, calendar: Calendar) -> CGFloat {
        let startOfDay = calendar.startOfDay(for: now)

        guard
            let eveningStart = calendar.date(bySettingHour: fallbackStartHour, minute: 0, second: 0, of: startOfDay),
            let morningEnd = calendar.date(bySettingHour: fallbackEndHour, minute: 0, second: 0, of: startOfDay)
        else {
            return 0
        }

        let eveningEnd = eveningStart.addingTimeInterval(fallbackRampDuration)
        let morningRampEnd = morningEnd.addingTimeInterval(fallbackMorningRampDuration)

        if now >= morningEnd, now < morningRampEnd {
            return 1 - linearRamp(now: now, start: morningEnd, end: morningRampEnd)
        }

        if now >= eveningStart, now < eveningEnd {
            return linearRamp(now: now, start: eveningStart, end: eveningEnd)
        }

        if now >= eveningEnd || now < morningEnd {
            return 1
        }

        return 0
    }

    private static func transitionBoundaries(for input: Input) -> [Date] {
        if let sunset = input.sunset {
            var points = [
                sunset.addingTimeInterval(-rampInBeforeSunset),
                sunset.addingTimeInterval(rampInAfterSunset)
            ]
            if let sunrise = input.sunrise {
                points.append(sunrise.addingTimeInterval(-rampOutBeforeSunrise))
                points.append(sunrise.addingTimeInterval(rampOutAfterSunrise))
            }
            return points
        }

        let calendar = input.calendar
        let startOfDay = calendar.startOfDay(for: input.now)
        guard
            let eveningStart = calendar.date(bySettingHour: fallbackStartHour, minute: 0, second: 0, of: startOfDay),
            let morningEnd = calendar.date(bySettingHour: fallbackEndHour, minute: 0, second: 0, of: startOfDay)
        else {
            return []
        }

        return [
            eveningStart,
            eveningStart.addingTimeInterval(fallbackRampDuration),
            morningEnd,
            morningEnd.addingTimeInterval(fallbackMorningRampDuration)
        ]
    }

    private static func linearRamp(now: Date, start: Date, end: Date) -> CGFloat {
        if now <= start { return 0 }
        if now >= end { return 1 }

        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 1 }
        return CGFloat(now.timeIntervalSince(start) / duration)
    }
}
