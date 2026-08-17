import Foundation

/// Glanceable Small-widget copy hierarchy derived from a precomputed snapshot.
public struct WeekFitSmallPresentation: Equatable, Sendable {
    public let stateLabel: String
    public let hero: String
    public let support: String
    public let nextHeader: String
    public let nextTitle: String
    public let showsNext: Bool
    public let nextKind: WeekFitWidgetSnapshot.NextActionKind

    public static func make(from snapshot: WeekFitWidgetSnapshot) -> WeekFitSmallPresentation {
        let state = WeekFitWidgetCopy.smallStateLabel(from: snapshot)
        let hero = WeekFitWidgetCopy.smallHero(from: snapshot)
        // Small stays glanceable: state + hero + next only — no supporting line.
        let nextTitle = WeekFitWidgetCopy.smallNextTitle(
            raw: snapshot.nextActionTitle,
            kind: snapshot.nextActionKind
        )
        let showsNext = snapshot.hasNextAction && !nextTitle.isEmpty
        let nextHeader = showsNext
            ? WeekFitWidgetCopy.smallNextHeader(
                time: snapshot.nextActionTime,
                phase: snapshot.nextActionPhase
            )
            : ""

        return WeekFitSmallPresentation(
            stateLabel: state,
            hero: hero,
            support: "",
            nextHeader: nextHeader,
            nextTitle: nextTitle,
            showsNext: showsNext,
            nextKind: snapshot.nextActionKind
        )
    }
}
