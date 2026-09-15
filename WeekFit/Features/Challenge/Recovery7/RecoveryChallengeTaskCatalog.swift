import Foundation

/// Versioned task catalogs so enrolled users keep their original semantics.
enum RecoveryChallengeTaskDefinitionVersion: Int, Codable, Sendable, CaseIterable {
    /// Legacy: Day 1 completion meant selecting a wind-down time.
    case v1 = 1
    /// Action-based: completion means confirming a real recovery action.
    case v2 = 2

    static let current: RecoveryChallengeTaskDefinitionVersion = .v2
}

enum RecoveryChallengeTaskCapability: Equatable, Sendable {
    case none
    case optionalSchedule
    case day5Breaks
    case day7FavoritePick
}

struct RecoveryChallengeTaskDefinition: Equatable, Sendable {
    var dayIndex: Int
    var titleKey: String
    var criterionKey: String
    var purposeKey: String
    var durationLabelKey: String?
    var alternativeKey: String?
    var acknowledgmentKey: String
    var capability: RecoveryChallengeTaskCapability
    var allowsMorningConfirmation: Bool
    var symbolName: String
}

enum RecoveryChallengeTaskCatalog {

    static func definition(
        dayIndex: Int,
        version: RecoveryChallengeTaskDefinitionVersion
    ) -> RecoveryChallengeTaskDefinition? {
        guard (1...RecoveryChallengeConfig.dayCount).contains(dayIndex) else { return nil }
        switch version {
        case .v1:
            return v1Definitions[dayIndex]
        case .v2:
            return v2Definitions[dayIndex]
        }
    }

    static func allDefinitions(
        version: RecoveryChallengeTaskDefinitionVersion
    ) -> [RecoveryChallengeTaskDefinition] {
        (1...RecoveryChallengeConfig.dayCount).compactMap { definition(dayIndex: $0, version: version) }
    }

    // MARK: - v2 (action challenge)

    private static let v2Definitions: [Int: RecoveryChallengeTaskDefinition] = [
        1: .init(
            dayIndex: 1,
            titleKey: "challenge.recovery7.v2.task.1.title",
            criterionKey: "challenge.recovery7.v2.task.1.criterion",
            purposeKey: "challenge.recovery7.v2.task.1.purpose",
            durationLabelKey: "challenge.recovery7.v2.task.1.duration",
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.v2.task.1.ack",
            capability: .optionalSchedule,
            allowsMorningConfirmation: true,
            symbolName: "iphone.slash"
        ),
        2: .init(
            dayIndex: 2,
            titleKey: "challenge.recovery7.v2.task.2.title",
            criterionKey: "challenge.recovery7.v2.task.2.criterion",
            purposeKey: "challenge.recovery7.v2.task.2.purpose",
            durationLabelKey: "challenge.recovery7.v2.task.2.duration",
            alternativeKey: "challenge.recovery7.v2.task.2.alternative",
            acknowledgmentKey: "challenge.recovery7.v2.task.2.ack",
            capability: .none,
            allowsMorningConfirmation: false,
            symbolName: "figure.cooldown"
        ),
        3: .init(
            dayIndex: 3,
            titleKey: "challenge.recovery7.v2.task.3.title",
            criterionKey: "challenge.recovery7.v2.task.3.criterion",
            purposeKey: "challenge.recovery7.v2.task.3.purpose",
            durationLabelKey: "challenge.recovery7.v2.task.3.duration",
            alternativeKey: "challenge.recovery7.v2.task.3.alternative",
            acknowledgmentKey: "challenge.recovery7.v2.task.3.ack",
            capability: .none,
            allowsMorningConfirmation: false,
            symbolName: "figure.walk"
        ),
        4: .init(
            dayIndex: 4,
            titleKey: "challenge.recovery7.v2.task.4.title",
            criterionKey: "challenge.recovery7.v2.task.4.criterion",
            purposeKey: "challenge.recovery7.v2.task.4.purpose",
            durationLabelKey: "challenge.recovery7.v2.task.4.duration",
            alternativeKey: "challenge.recovery7.v2.task.4.alternative",
            acknowledgmentKey: "challenge.recovery7.v2.task.4.ack",
            capability: .none,
            allowsMorningConfirmation: false,
            symbolName: "sparkles"
        ),
        5: .init(
            dayIndex: 5,
            titleKey: "challenge.recovery7.v2.task.5.title",
            criterionKey: "challenge.recovery7.v2.task.5.criterion",
            purposeKey: "challenge.recovery7.v2.task.5.purpose",
            durationLabelKey: "challenge.recovery7.v2.task.5.duration",
            alternativeKey: "challenge.recovery7.v2.task.5.alternative",
            acknowledgmentKey: "challenge.recovery7.v2.task.5.ack",
            capability: .day5Breaks,
            allowsMorningConfirmation: false,
            symbolName: "arrow.triangle.2.circlepath"
        ),
        6: .init(
            dayIndex: 6,
            titleKey: "challenge.recovery7.v2.task.6.title",
            criterionKey: "challenge.recovery7.v2.task.6.criterion",
            purposeKey: "challenge.recovery7.v2.task.6.purpose",
            durationLabelKey: "challenge.recovery7.v2.task.6.duration",
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.v2.task.6.ack",
            capability: .optionalSchedule,
            allowsMorningConfirmation: true,
            symbolName: "moon.zzz.fill"
        ),
        7: .init(
            dayIndex: 7,
            titleKey: "challenge.recovery7.v2.task.7.title",
            criterionKey: "challenge.recovery7.v2.task.7.criterion",
            purposeKey: "challenge.recovery7.v2.task.7.purpose",
            durationLabelKey: nil,
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.v2.task.7.ack",
            capability: .day7FavoritePick,
            allowsMorningConfirmation: false,
            symbolName: "heart.fill"
        )
    ]

    // MARK: - v1 (legacy)

    private static let v1Definitions: [Int: RecoveryChallengeTaskDefinition] = [
        1: .init(
            dayIndex: 1,
            titleKey: "challenge.recovery7.task.1.title",
            criterionKey: "challenge.recovery7.task.1.detail",
            purposeKey: "challenge.recovery7.task.1.detail",
            durationLabelKey: nil,
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.active.eveningPlanSet",
            capability: .optionalSchedule,
            allowsMorningConfirmation: false,
            symbolName: "moon.zzz.fill"
        ),
        2: .init(
            dayIndex: 2,
            titleKey: "challenge.recovery7.task.2.title",
            criterionKey: "challenge.recovery7.task.2.detail",
            purposeKey: "challenge.recovery7.task.2.detail",
            durationLabelKey: nil,
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.active.completedBody",
            capability: .none,
            allowsMorningConfirmation: false,
            symbolName: "figure.cooldown"
        ),
        3: .init(
            dayIndex: 3,
            titleKey: "challenge.recovery7.task.3.title",
            criterionKey: "challenge.recovery7.task.3.detail",
            purposeKey: "challenge.recovery7.task.3.detail",
            durationLabelKey: nil,
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.active.completedBody",
            capability: .none,
            allowsMorningConfirmation: false,
            symbolName: "figure.walk"
        ),
        4: .init(
            dayIndex: 4,
            titleKey: "challenge.recovery7.task.4.title",
            criterionKey: "challenge.recovery7.task.4.detail",
            purposeKey: "challenge.recovery7.task.4.detail",
            durationLabelKey: nil,
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.active.completedBody",
            capability: .none,
            allowsMorningConfirmation: false,
            symbolName: "sparkles"
        ),
        5: .init(
            dayIndex: 5,
            titleKey: "challenge.recovery7.task.5.title",
            criterionKey: "challenge.recovery7.task.5.detail",
            purposeKey: "challenge.recovery7.task.5.detail",
            durationLabelKey: nil,
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.active.completedBody",
            capability: .none,
            allowsMorningConfirmation: false,
            symbolName: "heart.fill"
        ),
        6: .init(
            dayIndex: 6,
            titleKey: "challenge.recovery7.task.6.title",
            criterionKey: "challenge.recovery7.task.6.detail",
            purposeKey: "challenge.recovery7.task.6.detail",
            durationLabelKey: nil,
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.active.completedBody",
            capability: .none,
            allowsMorningConfirmation: false,
            symbolName: "bed.double.fill"
        ),
        7: .init(
            dayIndex: 7,
            titleKey: "challenge.recovery7.task.7.title",
            criterionKey: "challenge.recovery7.task.7.detail",
            purposeKey: "challenge.recovery7.task.7.detail",
            durationLabelKey: nil,
            alternativeKey: nil,
            acknowledgmentKey: "challenge.recovery7.active.completedBody",
            capability: .day7FavoritePick,
            allowsMorningConfirmation: false,
            symbolName: "leaf.fill"
        )
    ]
}
