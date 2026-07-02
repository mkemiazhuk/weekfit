import Foundation

struct CoachDailyObservation: Codable, Equatable, Identifiable, Sendable {
    let dayKey: String
    let sleepMinutes: Int
    let recoveryPercent: Int
    let bedStartNormalizedMinutes: Int?

    var id: String { dayKey }

    var hasSleepSignal: Bool { sleepMinutes > 0 }

    var hasRecoverySignal: Bool { recoveryPercent > 0 }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let dayStart = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return ISO8601DateFormatter().string(from: dayStart)
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(fromDayKey dayKey: String, calendar: Calendar = .current) -> Date? {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }
}

enum CoachBeliefID: String, Codable, CaseIterable, Sendable {
    case sleepConsistencyRecovery
}

enum CoachBeliefMaturity: String, Codable, Sendable, Comparable {
    case watching
    case emerging
    case established

    static func < (lhs: Self, rhs: Self) -> Bool {
        rank(lhs) < rank(rhs)
    }

    private static func rank(_ maturity: CoachBeliefMaturity) -> Int {
        switch maturity {
        case .watching: return 0
        case .emerging: return 1
        case .established: return 2
        }
    }
}

struct CoachBelief: Codable, Equatable, Sendable {
    let id: CoachBeliefID
    var maturity: CoachBeliefMaturity
    var lastUpdated: Date
}

enum UnderstandingChange: String, Codable, Sendable {
    case emerged
    case strengthened
}

struct UnderstandingEvent: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let beliefID: CoachBeliefID
    let change: UnderstandingChange
    let maturity: CoachBeliefMaturity
    let createdAt: Date

    static func make(
        beliefID: CoachBeliefID,
        change: UnderstandingChange,
        maturity: CoachBeliefMaturity,
        createdAt: Date = Date()
    ) -> UnderstandingEvent {
        UnderstandingEvent(
            id: "\(beliefID.rawValue).\(change.rawValue).\(maturity.rawValue)",
            beliefID: beliefID,
            change: change,
            maturity: maturity,
            createdAt: createdAt
        )
    }
}

struct SleepConsistencyEvaluation: Equatable, Sendable {
    let consistentRecoveryAverage: Double
    let inconsistentRecoveryAverage: Double
    let consistentSampleCount: Int
    let inconsistentSampleCount: Int

    var recoveryDelta: Double {
        consistentRecoveryAverage - inconsistentRecoveryAverage
    }

    var hasMinimumSamples: Bool {
        consistentSampleCount >= 4 && inconsistentSampleCount >= 2
    }

    var hasEstablishedSamples: Bool {
        consistentSampleCount + inconsistentSampleCount >= 12
    }
}
