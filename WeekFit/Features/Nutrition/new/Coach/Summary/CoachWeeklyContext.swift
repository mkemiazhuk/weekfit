import Foundation

/// Compact evidence only. No raw samples, HealthKit UUIDs or recovery scores leave the device.
struct CoachWeeklyContext: Sendable {
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

    func facts() -> [String: [CoachEveningSummaryInput.Fact]] {
        typealias Fact = CoachEveningSummaryInput.Fact
        let recent = Array(days.suffix(7))
        let reference = Array(days.dropLast(7))
        let iso = ISO8601DateFormatter()
        func number(_ n: Double?) -> String { n.map { String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? "unknown" }
        func integer(_ n: Int?) -> String { n.map(String.init) ?? "unknown" }
        func date(_ d: Date?) -> String { d.map { iso.string(from: $0) } ?? "unknown" }
        func fact(_ id: String, _ text: String) -> Fact { .init(id: id, text: text) }
        var result: [String: [Fact]] = [:]
        result["recentSleep"] = recent.map { d in
            fact("history.sleep.\(d.day)", "Wake-day \(d.day): asleep=\(integer(d.sleepMinutes)) min; sleepStart=\(date(d.bedStart)); wake=\(date(d.wakeTime)); awake=\(integer(d.awakeMinutes)) min; awakenings=\(integer(d.awakenings)); estimated deep=\(integer(d.deepMinutes)) min; estimated REM=\(integer(d.remMinutes)) min.")
        }
        result["recentVitals"] = recent.map { d in
            fact("history.vitals.\(d.day)", "Wake-day \(d.day): HRV SDNN=\(number(d.hrv)) ms, n=\(d.hrvSamples), latest=\(date(d.hrvMeasuredAt)); resting HR=\(number(d.rhr)) bpm, n=\(d.rhrSamples), latest=\(date(d.rhrMeasuredAt)). Overnight-window medians; RHR is not sleeping heart rate. Sparse readings may not represent the whole night.")
        }
        result["recentActivity"] = recent.map { d in
            fact("history.activity.\(d.day)", "Local day \(d.day): active energy=\(number(d.activeKcal)) kcal; Apple Exercise=\(number(d.exerciseMinutes)) min (not necessarily workout duration). Day complete=\(d.complete). Missing samples do not prove inactivity; complete means calendar interval ended, not full device wear.")
        }
        // Keep the most recent sessions if the bounded evidence envelope is full.
        for (i, session) in sessions.suffix(12).enumerated() {
            result["recentActivity", default: []].append(fact("history.session.\(i)",
                "Recorded workout type=\(session.type); start=\(date(session.start)); end=\(date(session.end)); duration=\(session.minutes) min. Intensity unknown; distinct workout UUIDs may still overlap across sources."))
        }
        var baseline: [Fact] = [fact("history.coverage",
            "Recent window: \(recent.first?.day ?? "unknown") through \(recent.last?.day ?? "unknown"), \(recent.filter { $0.sleepMinutes != nil }.count)/7 sleep days, \(recent.filter { $0.hrv != nil }.count)/7 HRV days, \(recent.filter { $0.rhr != nil }.count)/7 RHR days. Baseline is the disjoint preceding 28 calendar days. Sleep belongs to wake-day; pair activity on D with sleep/vitals on D+1. Times are ISO instants; interpret in request timezone. No medical diagnosis or causal proof.")]
        baseline.append(fact("history.sessionsCoverage", "Recorded sessions in recent window=\(sessions.count); included=\(min(sessions.count, 12)). If truncated, do not infer workout frequency or exposure/control counts from the session list. Missing workouts do not establish no exercise."))
        func addBaseline(_ name: String, _ values: [Double]) {
            let sorted = values.filter(\.isFinite).sorted()
            let median: Double? = sorted.count >= 7
                ? (sorted[(sorted.count - 1) / 2] + sorted[sorted.count / 2]) / 2 : nil
            baseline.append(fact("baseline.\(name)",
                "Prior 28-day reference \(name): median=\(number(median)); observed days=\(sorted.count)/28; min=\(number(sorted.first)); max=\(number(sorted.last)). Fewer than 7 observed days means insufficient baseline. This range is descriptive, not a clinical threshold."))
        }
        addBaseline("sleepMinutes", reference.compactMap { $0.sleepMinutes.map(Double.init) })
        addBaseline("hrvSDNN", reference.compactMap(\.hrv))
        addBaseline("restingHR", reference.compactMap(\.rhr))
        addBaseline("activeKcal", reference.compactMap(\.activeKcal))
        addBaseline("exerciseMinutes", reference.compactMap(\.exerciseMinutes))
        // Noon-anchored local minutes avoid averaging 23:50 and 00:10 to noon.
        addBaseline("bedtimeLocalMinutesAfterNoon", reference.compactMap { day in
            guard let start = day.bedStart else { return nil }
            let minute = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
            return Double((minute + 720) % 1440)
        })
        result["baseline"] = baseline
        return result
    }
}
