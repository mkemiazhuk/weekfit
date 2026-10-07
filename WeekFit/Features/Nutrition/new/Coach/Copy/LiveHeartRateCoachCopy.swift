import Foundation

/// Zone-aware bilingual lines while a session has live HR.
enum LiveHeartRateCoachCopy {
    static func recommendation(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard let zone = input.liveHeartRateZone else { return nil }
        let range = HeartRateZones.definition(for: zone).bpmRangeLabel
        let effortEN = effortEnglish(for: zone)
        let effortRU = effortRussian(for: zone)
        let effortZH = effortChinese(for: zone)

        switch zone {
        case 1:
            return .en(
                "Zone 1 (\(range)) — \(effortEN). Easy pace is fine.",
                "Зона 1 (\(range)) — \(effortRU). Лёгкий темп нормален.",
                chinese: "1 区（\(range)）——\(effortZH)。轻松配速即可。"
            )
        case 2:
            return .en(
                "Zone 2 (\(range)) — \(effortEN). Hold this conversational pace.",
                "Зона 2 (\(range)) — \(effortRU). Держите разговорный темп.",
                chinese: "2 区（\(range)）——\(effortZH)。保持能交谈的配速。"
            )
        case 3:
            return .en(
                "Zone 3 (\(range)) — \(effortEN). Stay controlled; don't drift higher.",
                "Зона 3 (\(range)) — \(effortRU). Держите контроль, не уходите выше.",
                chinese: "3 区（\(range)）——\(effortZH)。保持可控，别再往上飘。"
            )
        case 4:
            return .en(
                "Zone 4 (\(range)) — \(effortEN). Ease back a notch and hold.",
                "Зона 4 (\(range)) — \(effortRU). Чуть сбавьте и держите ровнее.",
                chinese: "4 区（\(range)）——\(effortZH)。稍稍降一档并稳住。"
            )
        default:
            return .en(
                "Zone 5 (\(range)) — \(effortEN). Ease off until breathing settles.",
                "Зона 5 (\(range)) — \(effortRU). Сбросьте темп, пока дыхание не успокоится.",
                chinese: "5 区（\(range)）——\(effortZH)。降下来，直到呼吸平稳。"
            )
        }
    }

    static func assessment(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard let zone = input.liveHeartRateZone else { return nil }

        switch zone {
        case 1:
            return .en(
                "You're in Zone 1 — recovery effort.",
                "Вы в зоне 1 — восстановительная нагрузка.",
                chinese: "你在 1 区——恢复强度。"
            )
        case 2:
            return .en(
                "You're in Zone 2 — aerobic work.",
                "Вы в зоне 2 — аэробная работа.",
                chinese: "你在 2 区——有氧强度。"
            )
        case 3:
            return .en(
                "You're in Zone 3 — tempo effort.",
                "Вы в зоне 3 — темповая нагрузка.",
                chinese: "你在 3 区——节奏强度。"
            )
        case 4:
            return .en(
                "You're in Zone 4 — hard effort, stay controlled.",
                "Вы в зоне 4 — тяжёлая нагрузка, держите контроль.",
                chinese: "你在 4 区——高强度，保持可控。"
            )
        default:
            return .en(
                "You're in Zone 5 — max effort, protect the rest of this session.",
                "Вы в зоне 5 — максимум, берегите остаток тренировки.",
                chinese: "你在 5 区——极限强度，保护这节课的后半段。"
            )
        }
    }

    static func teaser(for input: CoachCopyBuildInput) -> CoachBilingualText? {
        guard let zone = input.liveHeartRateZone else { return nil }

        switch zone {
        case 1:
            return .en("Zone 1 — easy.", "Зона 1 — легко.", chinese: "1 区——轻松。")
        case 2:
            return .en("Zone 2 — aerobic.", "Зона 2 — аэробная.", chinese: "2 区——有氧。")
        case 3:
            return .en("Zone 3 — tempo.", "Зона 3 — темп.", chinese: "3 区——节奏。")
        case 4:
            return .en("Zone 4 — hard, ease back.", "Зона 4 — тяжело, сбавьте.", chinese: "4 区——偏强，稍降一点。")
        default:
            return .en("Zone 5 — max, ease off.", "Зона 5 — максимум, сбросьте.", chinese: "5 区——极限，降下来。")
        }
    }

    static func apply(to draft: CoachCopyRegistryScenarios.Draft, input: CoachCopyBuildInput) -> CoachCopyRegistryScenarios.Draft {
        LiveSessionCoachCopy.apply(to: draft, input: input)
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

    private static func effortChinese(for zone: Int) -> String {
        switch zone {
        case 1: return "轻松"
        case 2: return "有氧"
        case 3: return "节奏"
        case 4: return "偏强"
        default: return "极限"
        }
    }
}
