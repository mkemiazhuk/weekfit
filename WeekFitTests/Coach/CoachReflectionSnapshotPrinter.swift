import Foundation
@testable import WeekFit

enum CoachReflectionSnapshotPrinter {

    struct Layout: Equatable {
        let width: Int
        let guidance: CoachReflectionPreviewGuidance
        let reflectionOffer: ReflectionOffer?
    }

    static func render(_ layout: Layout) -> String {
        var lines: [String] = [
            "Coach Reflection Layout Snapshot",
            "WIDTH: \(layout.width)pt",
            "HAS_REFLECTION: \(layout.reflectionOffer != nil)",
            "---",
            "GUIDANCE_TITLE: \(layout.guidance.title)",
            "GUIDANCE_ASSESSMENT: \(layout.guidance.assessment)",
            "GUIDANCE_RECOMMENDATION: \(layout.guidance.recommendation)",
            "GUIDANCE_NEXT: \(layout.guidance.nextAction)"
        ]

        if let offer = layout.reflectionOffer {
            let content = CoachReflectionPresentation.content(for: offer)
            lines.append("---")
            lines.append("REFLECTION_LEAD_IN: \(content.leadIn)")
            lines.append("REFLECTION_MESSAGE: \(content.message)")
            lines.append("REFLECTION_KIND: \(offer.kind.rawValue)")
            lines.append("PAUSE_REASON: \(offer.pauseReason)")
        }

        return lines.joined(separator: "\n")
    }

    static let guidanceOnly = Layout(
        width: 390,
        guidance: CoachReflectionPreviewFixtures.defaultGuidance,
        reflectionOffer: nil
    )

    static let guidanceWithReflection = Layout(
        width: 390,
        guidance: CoachReflectionPreviewFixtures.defaultGuidance,
        reflectionOffer: CoachReflectionPreviewFixtures.emergingOffer
    )

    static let longRussian = Layout(
        width: 390,
        guidance: CoachReflectionPreviewFixtures.eveningGuidance,
        reflectionOffer: CoachReflectionPreviewFixtures.longRussianOffer
    )

    static let narrowWidth = Layout(
        width: 320,
        guidance: CoachReflectionPreviewFixtures.defaultGuidance,
        reflectionOffer: CoachReflectionPreviewFixtures.emergingOffer
    )

    static let eveningSettled = Layout(
        width: 390,
        guidance: CoachReflectionPreviewFixtures.eveningGuidance,
        reflectionOffer: CoachReflectionPreviewFixtures.eveningOffer
    )
}
