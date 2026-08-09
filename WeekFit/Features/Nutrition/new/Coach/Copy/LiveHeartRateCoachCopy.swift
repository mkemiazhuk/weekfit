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
        let bpmPartEN: String
        let bpmPartRU: String
        if let bpm = input.liveHeartRateBPM {
            bpmPartEN = " at \(bpm) bpm"
            bpmPartRU = " · \(bpm) уд/мин"
        } else {
            bpmPartEN = ""
            bpmPartRU = ""
        }

        switch zone {
        case 1:
            return .en(
                "You're in Zone 1\(bpmPartEN) — recovery effort.",
                "Вы в зоне 1\(bpmPartRU) — восстановительная нагрузка."
            )
        case 2:
            return .en(
                "You're in Zone 2\(bpmPartEN) — aerobic work.",
                "Вы в зоне 2\(bpmPartRU) — аэробная работа."
            )
        case 3:
            return .en(
                "You're in Zone 3\(bpmPartEN) — tempo effort.",
                "Вы в зоне 3\(bpmPartRU) — темповая нагрузка."
            )
        case 4:
            return .en(
                "You're in Zone 4\(bpmPartEN) — hard effort, stay controlled.",
                "Вы в зоне 4\(bpmPartRU) — тяжёлая нагрузка, держите контроль."
            )
        default:
            return .en(
                "You're in Zone 5\(bpmPartEN) — max effort, protect the rest of this session.",
                "Вы в зоне 5\(bpmPartRU) — максимум, берегите остаток тренировки."
            )
        }
    }

    static func teaser(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard let zone = input.liveHeartRateZone else { return nil }
        let bpmSuffix: String
        if let bpm = input.liveHeartRateBPM {
            bpmSuffix = " · \(bpm)"
        } else {
            bpmSuffix = ""
        }

        switch zone {
        case 1:
            return .en("Zone 1\(bpmSuffix) — easy.", "Зона 1\(bpmSuffix) — легко.")
        case 2:
            return .en("Zone 2\(bpmSuffix) — aerobic.", "Зона 2\(bpmSuffix) — аэробная.")
        case 3:
            return .en("Zone 3\(bpmSuffix) — tempo.", "Зона 3\(bpmSuffix) — темп.")
        case 4:
            return .en("Zone 4\(bpmSuffix) — hard, ease back.", "Зона 4\(bpmSuffix) — тяжело, сбавьте.")
        default:
            return .en("Zone 5\(bpmSuffix) — max, ease off.", "Зона 5\(bpmSuffix) — максимум, сбросьте.")
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
