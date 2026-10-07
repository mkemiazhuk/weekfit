import Foundation

/// Compact cross-day memory for Coach Assistant (not a full transcript).
/// Feelings are day-scoped and never treated as “still true” on later days.
struct CoachAssistantMemoryState: Equatable, Sendable {
    var days: [CoachAssistantDayMemory]
    /// Lasting preference when the user answers Regular / Vegetarian.
    var prefersVegetarian: Bool?
    var offeredMealIDs: [String]
    /// Last opening line variant — avoid repeating the same greeting on a new chat.
    var lastOpeningVariantID: String?

    static let empty = CoachAssistantMemoryState(
        days: [],
        prefersVegetarian: nil,
        offeredMealIDs: [],
        lastOpeningVariantID: nil
    )
    static let maxDays = 14
}

extension CoachAssistantMemoryState: Codable {
    enum CodingKeys: String, CodingKey {
        case days, prefersVegetarian, offeredMealIDs, lastOpeningVariantID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try container.decodeIfPresent([CoachAssistantDayMemory].self, forKey: .days) ?? []
        prefersVegetarian = try container.decodeIfPresent(Bool.self, forKey: .prefersVegetarian)
        offeredMealIDs = try container.decodeIfPresent([String].self, forKey: .offeredMealIDs) ?? []
        lastOpeningVariantID = try container.decodeIfPresent(String.self, forKey: .lastOpeningVariantID)
    }
}

struct CoachAssistantDayMemory: Codable, Equatable, Sendable {
    var dayKey: String
    /// Self-report for that calendar day only.
    var feeling: CoachFeelingKind?
    var areasVisited: [CoachAssistantArea]
    var questionIDs: [String]
    var recommendationIDs: [String]
    var unresolvedFollowUp: CoachAssistantFollowUpKind?
    var insightID: String?
}

enum CoachAssistantFollowUpKind: String, Codable, Sendable {
    /// User was offered a lighter Plan / easier session.
    case easierSession
    /// User was pointed at protein / leftover nutrition.
    case nutritionProtein
    /// Retired weekly-focus follow-up. Kept for decoding older memory only.
    case recoveryFocus
}

enum CoachAssistantMemoryStore {
    static let storageKey = "coach.assistant.memory.v1"
    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    static func load() -> CoachAssistantMemoryState {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(CoachAssistantMemoryState.self, from: data) else {
            return .empty
        }
        return state
    }

    static func save(_ state: CoachAssistantMemoryState) {
        lock.lock()
        defer { lock.unlock() }
        var trimmed = state
        if trimmed.days.count > CoachAssistantMemoryState.maxDays {
            trimmed.days = Array(trimmed.days.prefix(CoachAssistantMemoryState.maxDays))
        }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func clear() {
        lock.lock()
        defaults.removeObject(forKey: storageKey)
        lock.unlock()
    }

    static func useDefaults(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func resetDefaults() {
        lock.lock()
        defaults = .standard
        lock.unlock()
    }

    static func day(
        _ dayKey: String,
        in state: CoachAssistantMemoryState
    ) -> CoachAssistantDayMemory? {
        state.days.first { $0.dayKey == dayKey }
    }

    static func recentQuestionIDs(
        _ state: CoachAssistantMemoryState,
        excludingDayKey: String? = nil,
        limit: Int = 24
    ) -> [String] {
        var ids: [String] = []
        for day in state.days where day.dayKey != excludingDayKey {
            ids.append(contentsOf: day.questionIDs)
            if ids.count >= limit { break }
        }
        return Array(ids.prefix(limit))
    }

    static func recentRecommendationIDs(
        _ state: CoachAssistantMemoryState,
        excludingDayKey: String? = nil,
        limit: Int = 16
    ) -> [String] {
        var ids: [String] = []
        for day in state.days where day.dayKey != excludingDayKey {
            ids.append(contentsOf: day.recommendationIDs)
            if ids.count >= limit { break }
        }
        return Array(ids.prefix(limit))
    }

    /// Most recent unresolved follow-up from a prior day (not today).
    static func priorUnresolved(
        _ state: CoachAssistantMemoryState,
        todayKey: String
    ) -> (dayKey: String, kind: CoachAssistantFollowUpKind)? {
        for day in state.days where day.dayKey != todayKey {
            if let kind = day.unresolvedFollowUp {
                return (day.dayKey, kind)
            }
        }
        return nil
    }

    static func upsertDay(
        _ entry: CoachAssistantDayMemory,
        into state: inout CoachAssistantMemoryState
    ) {
        if let index = state.days.firstIndex(where: { $0.dayKey == entry.dayKey }) {
            state.days[index] = entry
        } else {
            state.days.insert(entry, at: 0)
        }
        state.days.sort { $0.dayKey > $1.dayKey }
        if state.days.count > CoachAssistantMemoryState.maxDays {
            state.days = Array(state.days.prefix(CoachAssistantMemoryState.maxDays))
        }
    }
}
