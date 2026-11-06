import SwiftUI

enum ActivityBadgePalette {
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let leaf = WeekFitSemanticMetricTokens.activity
    static let lavender = WeekFitSemanticMetricTokens.recovery
    static let apricot = Color(red: 0.86, green: 0.55, blue: 0.36)

    static func tint(_ category: ActivityBadgeCategory) -> Color {
        switch category {
        case .activity: return leaf
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

    var body: some View {
        ZStack {
            if let sculpture {
                Image(sculpture)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .saturation(locked ? 0.55 : 1)
                    .opacity(locked ? 0.92 : 1)
                    .shadow(color: Color.black.opacity(locked ? 0.12 : 0.22), radius: size * 0.08, y: size * 0.04)
            } else {
                Image(medalName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .saturation(locked ? 0 : 1)
                    .opacity(locked ? 0.5 : 1)
                    .shadow(color: Color.black.opacity(locked ? 0.16 : 0.38), radius: size * 0.1, y: size * 0.05)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.09, weight: .semibold))
                    .foregroundStyle(ActivityBadgePalette.cream)
                    .opacity(locked ? 0.7 : 1)
                    .offset(x: size * 0.012, y: size * -0.102)
            }
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(9, size * 0.11), weight: .bold))
                    .foregroundStyle(ActivityBadgePalette.cream)
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.62)))
                    .offset(x: size * 0.30, y: size * 0.28)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var sculpture: String? {
        guard let artworkID else { return nil }
        return ActivityBadgeArt.asset(for: artworkID)
    }

    private var medalName: String {
        switch category {
        case .activity: return "badge-ribbon-activity"
        case .recovery: return "badge-ribbon-recovery"
        case .habit: return "badge-ribbon-habit"
        }
    }
}

enum ActivityBadgeArt {
    static func asset(for awardID: String) -> String? {
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
        case "recovery.sauna": return "badge-art-sauna"
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
