import SwiftUI

enum ActivityBadgePalette {
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let leaf = WeekFitSemanticMetricTokens.activity
    static let lavender = WeekFitSemanticMetricTokens.recovery
    static let apricot = Color(red: 0.86, green: 0.55, blue: 0.36)

    static func tint(_ category: ActivityBadgeCategory) -> Color {
        switch category {
        case .activity, .energy: return leaf
        case .recovery: return lavender
        case .habit: return apricot
        }
    }
}

struct ActivityBadgeRibbon: View {
    let symbol: String
    let category: ActivityBadgeCategory
    var artworkID: String? = nil
    var locked: Bool = false
    var size: CGFloat = 112

    private var milestone: String? {
        guard let artworkID else { return nil }
        for marker in [".count.", ".km."] {
            if let range = artworkID.range(of: marker) {
                return String(artworkID[range.upperBound...])
            }
        }
        return nil
    }

    /// Count plates from the example sheets already include the clay digit.
    private var showsCountDisc: Bool {
        guard let milestone, let sculpture else { return milestone != nil }
        return !sculpture.hasSuffix("-\(milestone)")
    }

    private var countColor: Color {
        switch milestone {
        case "5": return ActivityBadgePalette.apricot
        case "10": return ActivityBadgePalette.lavender
        case "25": return ActivityBadgePalette.leaf
        case "50": return ActivityBadgePalette.lavender
        default: return ActivityBadgePalette.tint(category)
        }
    }

    var body: some View {
        ZStack {
            if let sculpture {
                Image(sculpture)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(medalName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(locked ? 0.5 : 1)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.09, weight: .semibold))
                    .foregroundStyle(ActivityBadgePalette.cream)
                    .opacity(locked ? 0.7 : 1)
                    .offset(x: size * 0.012, y: size * -0.102)
            }
            if showsCountDisc, let milestone {
                Text(milestone)
                    .font(.system(size: size * 0.16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(minWidth: size * 0.27, minHeight: size * 0.27)
                    .background(countColor, in: Circle())
                    .overlay(Circle().strokeBorder(ActivityBadgePalette.cream, lineWidth: size * 0.018))
                    .offset(x: -size * 0.28, y: size * 0.26)
            }
        }
        .saturation(locked ? 0 : 1)
        .opacity(locked ? 0.42 : 1)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var sculpture: String? {
        guard let artworkID else { return nil }
        return ActivityBadgeArt.asset(for: artworkID)
    }

    private var medalName: String {
        switch category {
        case .activity, .energy: return "badge-ribbon-activity"
        case .recovery: return "badge-ribbon-recovery"
        case .habit: return "badge-ribbon-habit"
        }
    }
}

enum ActivityBadgeArt {
    static func asset(for awardID: String) -> String? {
        switch awardID {
        case "activity.cycling.count.5": return "badge-art-cycling-5"
        case "activity.cycling.count.10": return "badge-art-cycling-10"
        case "activity.cycling.count.25": return "badge-art-cycling-25"
        case "activity.cycling.count.50": return "badge-art-cycling-50"
        case "activity.cycling.streak": return "badge-art-cycling-streak"
        case "activity.cycling.record": return "badge-art-cycling-record"
        case "activity.cycling.km.1": return "badge-art-cycling-km-1"
        case "activity.cycling.km.2": return "badge-art-cycling-km-2"
        case "activity.cycling.km.3": return "badge-art-cycling-km-3"
        case "activity.cycling.km.5": return "badge-art-cycling-km-5"
        case "recovery.walk.km.1": return "badge-art-walk-km-1"
        case "recovery.walk.km.2": return "badge-art-walk-km-2"
        case "recovery.walk.km.3": return "badge-art-walk-km-3"
        case "recovery.walk.km.5": return "badge-art-walk-km-5"
        case "energy.kcal.300": return "badge-art-kcal-300"
        case "energy.kcal.500": return "badge-art-kcal-500"
        case "energy.kcal.1000": return "badge-art-kcal-1000"
        case "energy.kcal.2000": return "badge-art-kcal-2000"
        case "energy.kcal.3000": return "badge-art-kcal-3000"
        case "habit.drink-water.record": return "badge-art-water-record"
        default: break
        }
        if awardID.hasPrefix(ActivityBadgeEngine.customPrefix) {
            return "badge-art-checkin"
        }
        switch ActivityBadgeEngine.awardBaseID(awardID) {
        case "activity.cycling": return "badge-art-cycling"
        case "activity.running": return "badge-art-running"
        case "activity.swimming": return "badge-art-swim"
        case "activity.hiking": return "badge-art-hike"
        case "activity.snowboarding": return "badge-art-snowboard"
        case "activity.alpine-skiing": return "badge-art-ski"
        case "activity.upper-body": return "badge-art-upper"
        case "activity.core": return "badge-art-core"
        case "activity.lower-body": return "badge-art-lower"
        case "activity.full-body": return "badge-art-full"
        case "activity.tennis": return "badge-art-tennis"
        case "activity.padel": return "badge-art-padel"
        case "activity.squash": return "badge-art-squash"
        case "activity.hiit": return "badge-art-hiit"
        case "recovery.stretching": return "badge-art-stretch"
        case "recovery.walk": return "badge-art-walk"
        case "recovery.sauna": return "badge-art-sauna-kcal"
        case "recovery.yoga": return "badge-art-yoga"
        case "recovery.breathing": return "badge-art-breathing"
        case "habit.drink-water": return "badge-art-water"
        case "habit.sleep-routine": return "badge-art-sleep"
        case "habit.no-screens": return "badge-art-screens"
        case "habit.morning-routine": return "badge-art-morning"
        default: return nil
        }
    }
}
