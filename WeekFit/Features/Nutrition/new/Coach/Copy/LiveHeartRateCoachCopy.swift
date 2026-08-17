import Foundation

/// Zone-aware bilingual lines while a session has live HR.
enum LiveHeartRateCoachCopy {
    static func recommendation(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard let zone = input.liveHeartRateZone else { return nil }
        let range = HeartRateZones.definition(for: zone).bpmRangeLabel
        let effortEN = effortEnglish(for: zone)
        let effortRU = effortRussian(for: zone)

        switch zone {
        case 1:
            return .en(
                "Zone 1 (\(range)) — \(effortEN). Easy pace is fine.",
                "Зона 1 (\(range)) — \(effortRU). Лёгкий темп нормален."
            )
        case 2:
            return .en(
                "Zone 2 (\(range)) — \(effortEN). Hold this conversational pace.",
                "Зона 2 (\(range)) — \(effortRU). Держите разговорный темп."
            )
        case 3:
            return .en(
                "Zone 3 (\(range)) — \(effortEN). Stay controlled; don't drift higher.",
                "Зона 3 (\(range)) — \(effortRU). Держите контроль, не уходите выше."
            )
        case 4:
            return .en(
                "Zone 4 (\(range)) — \(effortEN). Ease back a notch and hold.",
                "Зона 4 (\(range)) — \(effortRU). Чуть сбавьте и держите ровнее."
            )
        default:
            return .en(
                "Zone 5 (\(range)) — \(effortEN). Ease off until breathing settles.",
                "Зона 5 (\(range)) — \(effortRU). Сбросьте темп, пока дыхание не успокоится."
            )
        }
    }

    static func assessment(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard let zone = input.liveHeartRateZone else { return nil }

        switch zone {
        case 1:
            return .en(
                "You're in Zone 1 — recovery effort.",
                "Вы в зоне 1 — восстановительная нагрузка."
            )
        case 2:
            return .en(
                "You're in Zone 2 — aerobic work.",
                "Вы в зоне 2 — аэробная работа."
            )
        case 3:
            return .en(
                "You're in Zone 3 — tempo effort.",
                "Вы в зоне 3 — темповая нагрузка."
            )
        case 4:
            return .en(
                "You're in Zone 4 — hard effort, stay controlled.",
                "Вы в зоне 4 — тяжёлая нагрузка, держите контроль."
            )
        default:
            return .en(
                "You're in Zone 5 — max effort, protect the rest of this session.",
                "Вы в зоне 5 — максимум, берегите остаток тренировки."
            )
        }
    }

    static func teaser(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard let zone = input.liveHeartRateZone else { return nil }

        switch zone {
        case 1:
            return .en("Zone 1 — easy.", "Зона 1 — легко.")
        case 2:
            return .en("Zone 2 — aerobic.", "Зона 2 — аэробная.")
        case 3:
            return .en("Zone 3 — tempo.", "Зона 3 — темп.")
        case 4:
            return .en("Zone 4 — hard, ease back.", "Зона 4 — тяжело, сбавьте.")
        default:
            return .en("Zone 5 — max, ease off.", "Зона 5 — максимум, сбросьте.")
        }
    }

    static func apply(to draft: CoachCopyRegistryScenarios.Draft, input: CoachCopyBuildInput) -> CoachCopyRegistryScenarios.Draft {
        guard input.liveHeartRateZone != nil else { return draft }
        return CoachCopyRegistryScenarios.Draft(
            assessment: assessment(for: input) ?? draft.assessment,
            recommendation: recommendation(for: input) ?? draft.recommendation,
            avoid: HeartRateZones.isElevated(input.liveHeartRateZone ?? 0)
                ? .en(
                    "Don't push into a higher zone while heart rate is already here.",
                    "Не давите в более высокую зону при таком пульсе."
                )
                : draft.avoid,
            nextAction: HeartRateZones.isCritical(input.liveHeartRateZone ?? 0)
                ? .en(
                    "Drop to Zone 3 or easier for one minute, then reassess.",
                    "Минуту в зоне 3 или ниже — потом оцените самочувствие."
                )
                : draft.nextAction
        )
    }

    private static func effortEnglish(for zone: Int) -> String {
        switch zone {
        case 1: return "easy"
        case 2: return "aerobic"
        case 3: return "tempo"
        case 4: return "hard"
        default: return "max"
        }
    }

    private static func effortRussian(for zone: Int) -> String {
        switch zone {
        case 1: return "легко"
        case 2: return "аэробная"
        case 3: return "темп"
        case 4: return "тяжело"
        default: return "максимум"
        }
    }
}
