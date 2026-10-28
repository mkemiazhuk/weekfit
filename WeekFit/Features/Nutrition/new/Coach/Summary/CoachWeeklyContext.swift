import Foundation

/// Compact evidence only. No raw samples, HealthKit UUIDs or recovery scores leave the device.
struct CoachWeeklyContext: Sendable {
    /// Max sessions included as individual facts (day summaries are always kept).
    /// Kept under the server envelope (40 facts/group) together with 7 daily activity rows + coverage.
    static let maxIncludedSessions = 24

    struct Day: Sendable {
        let day: String
        let complete: Bool
        let sleepMinutes: Int?
        let bedStart: Date?
        let wakeTime: Date?
        let awakeMinutes: Int?
        let awakenings: Int?
        let deepMinutes: Int?
        let remMinutes: Int?
        let hrv: Double?
        let hrvSamples: Int
        let hrvMeasuredAt: Date?
        let rhr: Double?
        let rhrSamples: Int
        let rhrMeasuredAt: Date?
        let activeKcal: Double?
        let exerciseMinutes: Double?
    }
    struct Session: Encodable, Sendable {
        let type: String
        let start: Date
        let end: Date
        let minutes: Int
    }
    let days: [Day] // chronological, oldest first
    let sessions: [Session]
    let calendar: Calendar
    /// Wall-clock when this context was assembled on-device (coverage freshness).
    let assembledAt: Date

    init(days: [Day], sessions: [Session], calendar: Calendar, assembledAt: Date = Date()) {
        self.days = days
        self.sessions = sessions
        self.calendar = calendar
        self.assembledAt = assembledAt
    }

    func facts() -> [String: [CoachEveningSummaryInput.Fact]] {
        typealias Fact = CoachEveningSummaryInput.Fact
        let recent = Array(days.suffix(7))
        let reference = Array(days.dropLast(7))
        let iso = ISO8601DateFormatter()
        func number(_ n: Double?) -> String { n.map { String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? "unknown" }
        func integer(_ n: Int?) -> String { n.map(String.init) ?? "unknown" }
        func date(_ d: Date?) -> String { d.map { iso.string(from: $0) } ?? "unknown" }
        func fact(_ id: String, _ text: String) -> Fact { .init(id: id, text: String(text.prefix(500))) }
        var result: [String: [Fact]] = [:]

        result["recentSleep"] = recent.map { d in
            let status: String
            if d.sleepMinutes != nil {
                status = "samples_present"
            } else if d.complete {
                status = "no_samples_for_wake_day"
            } else {
                status = "not_yet_synced_or_incomplete_day"
            }
            return fact(
                "history.sleep.\(d.day)",
                "Wake-day \(d.day): asleep=\(integer(d.sleepMinutes)) min; sleepStart=\(date(d.bedStart)); wake=\(date(d.wakeTime)); awakeMin=\(integer(d.awakeMinutes)); awakenings=\(integer(d.awakenings)); deepMin=\(integer(d.deepMinutes)); remMin=\(integer(d.remMinutes)); coverage=\(status)."
            )
        }

        result["recentVitals"] = recent.map { d in
            fact(
                "history.vitals.\(d.day)",
                "Wake-day \(d.day): hrvSDNN=\(number(d.hrv)) ms; hrvSamples=\(d.hrvSamples); hrvLatest=\(date(d.hrvMeasuredAt)); rhr=\(number(d.rhr)) bpm; rhrSamples=\(d.rhrSamples); rhrLatest=\(date(d.rhrMeasuredAt))."
            )
        }

        // Always keep full daily activity summaries (7).
        var activityFacts: [Fact] = recent.map { d in
            fact(
                "history.activity.\(d.day)",
                "Local day \(d.day): energy=\(number(d.activeKcal)) kcal; exerciseMin=\(number(d.exerciseMinutes)); complete=\(d.complete)."
            )
        }

        let sortedSessions = sessions.sorted { $0.start < $1.start }
        let includedSessions = Array(sortedSessions.suffix(Self.maxIncludedSessions))
        let truncated = sortedSessions.count > includedSessions.count
        activityFacts.append(fact(
            "history.sessionsCoverage",
            "Sessions in recent 7 days: total=\(sortedSessions.count); included=\(includedSessions.count); truncated=\(truncated); selection=most_recent_by_start."
        ))
        for (i, session) in includedSessions.enumerated() {
            activityFacts.append(fact(
                "history.session.\(i)",
                "type=\(session.type); start=\(date(session.start)); end=\(date(session.end)); durationMin=\(session.minutes)."
            ))
        }
        result["recentActivity"] = activityFacts

        var baseline: [Fact] = [fact(
            "history.coverage",
            "Recent window \(recent.first?.day ?? "unknown")..\(recent.last?.day ?? "unknown"). Sleep days=\(recent.filter { $0.sleepMinutes != nil }.count)/7; HRV days=\(recent.filter { $0.hrv != nil }.count)/7; RHR days=\(recent.filter { $0.rhr != nil }.count)/7. Baseline is the preceding 28 calendar days. Sleep belongs to wake-day. AssembledAt=\(date(assembledAt))."
        )]

        func addBaseline(_ name: String, _ values: [Double], aggregation: String) {
            let sorted = values.filter(\.isFinite).sorted()
            let median: Double? = sorted.count >= 7
                ? (sorted[(sorted.count - 1) / 2] + sorted[sorted.count / 2]) / 2 : nil
            baseline.append(fact(
                "baseline.\(name)",
                "Prior 28-day \(name): window=\(reference.first?.day ?? "unknown")..\(reference.last?.day ?? "unknown"); median=\(number(median)); observed days=\(sorted.count)/28; min=\(number(sorted.first)); max=\(number(sorted.last)); aggregation=\(aggregation)."
            ))
        }
        addBaseline("sleepMinutes", reference.compactMap { $0.sleepMinutes.map(Double.init) }, aggregation: "wake_day_asleep_minutes")
        addBaseline("hrvSDNN", reference.compactMap(\.hrv), aggregation: "overnight_sleep_window_median")
        addBaseline("restingHR", reference.compactMap(\.rhr), aggregation: "overnight_sleep_window_median")
        addBaseline("activeKcal", reference.compactMap(\.activeKcal), aggregation: "calendar_day_sum")
        addBaseline("exerciseMinutes", reference.compactMap(\.exerciseMinutes), aggregation: "calendar_day_sum")
        addBaseline("bedtimeLocalMinutesAfterNoon", reference.compactMap { day in
            guard let start = day.bedStart else { return nil }
            let minute = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
            return Double((minute + 720) % 1440)
        }, aggregation: "local_bed_start_minutes_after_noon")

        // Compact dated prior-28 values so the model can check multi-day links without inventing them from min/max.
        func compactDaily(_ name: String, _ pick: (Day) -> Double?) {
            let pairs = reference.compactMap { day -> String? in
                guard let value = pick(day) else { return nil }
                return "\(day.day)=\(String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), value))"
            }
            guard !pairs.isEmpty else { return }
            baseline.append(fact(
                "baseline.\(name).daily",
                "\(name) by day: \(pairs.joined(separator: ", ")). Missing days omitted."
            ))
        }
        compactDaily("hrvSDNN") { $0.hrv }
        compactDaily("restingHR") { $0.rhr }
        compactDaily("activeKcal") { $0.activeKcal }
        compactDaily("sleepMinutes") { $0.sleepMinutes.map(Double.init) }

        result["baseline"] = baseline
        return result
    }
}
