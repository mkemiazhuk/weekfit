import SwiftUI
import UIKit

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
    @Environment(\.weekFitPalette) private var palette
    let symbol: String
    let category: ActivityBadgeCategory
    var artworkID: String? = nil
    var locked: Bool = false
    var size: CGFloat = 112

    private var accent: Color {
        guard let artworkID else { return ActivityBadgePalette.tint(category) }
        switch ActivityBadgeEngine.awardBaseID(artworkID) {
        case "activity.running", "activity.upper-body", "activity.tennis", "habit.drink-water":
            return ActivityBadgePalette.apricot
        case "activity.swimming", "activity.snowboarding", "activity.squash", "recovery.breathing":
            return ActivityBadgePalette.lavender
        default:
            return ActivityBadgePalette.tint(category)
        }
    }

    private var milestone: String? {
        guard let artworkID, let range = artworkID.range(of: ".count.") else { return nil }
        return String(artworkID[range.upperBound...])
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [palette.appScreenBackground, locked ? Color.gray.opacity(0.12) : accent.opacity(0.2)],
                    center: .init(x: 0.4, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.7
                ))
                .overlay {
                    Circle().strokeBorder(ActivityBadgePalette.cream.opacity(0.9), lineWidth: max(2, size * 0.025))
                }
                .shadow(color: (locked ? Color.gray : accent).opacity(0.12), radius: size * 0.07, y: size * 0.03)
            if let artworkID, let artwork = ActivityBadgeArt.image(for: artworkID) {
                Image(uiImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .saturation(locked ? 0 : 1)
                    .opacity(locked ? 0.7 : 1)
                    .clipShape(Circle())
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(locked ? palette.textSecondary : accent)
            }
            if let milestone {
                Text(milestone)
                    .font(.system(size: size * 0.16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(minWidth: size * 0.27, minHeight: size * 0.27)
                    .background((locked ? Color.gray : accent).gradient, in: Circle())
                    .overlay(Circle().strokeBorder(ActivityBadgePalette.cream, lineWidth: size * 0.018))
                    .offset(x: -size * 0.32, y: size * 0.30)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

}

enum ActivityBadgeArt {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for awardID: String) -> UIImage? {
        let baseID = ActivityBadgeEngine.awardBaseID(awardID)
        if let cached = cache.object(forKey: baseID as NSString) { return cached }
        let ids = ActivityBadgeCatalog.definitions.map(\.id)
        let board: String
        let index: Int
        let columns: Int
        let x: [Int]
        let y: [Int]
        let crop: Int
        if let position = ids.prefix(8).firstIndex(of: baseID) {
            board = "award-board-activity-one"
            index = position
            columns = 4
            x = [95, 505, 938, 1350]
            y = [10, 430]
            crop = 360
        } else if let position = ids.dropFirst(8).prefix(6).firstIndex(of: baseID) {
            board = "award-board-activity-two"
            index = position - 8
            columns = 3
            x = [100, 580, 1060]
            y = [10, 500]
            crop = 380
        } else if let position = ids.dropFirst(14).prefix(5).firstIndex(of: baseID) {
            board = "award-board-recovery"
            index = position - 14
            columns = 3
            x = [100, 580, 1060]
            y = [10, 500]
            crop = 380
        } else {
            board = "award-board-habits"
            index = ids.dropFirst(19).firstIndex(of: baseID).map { $0 - 19 } ?? 4
            columns = 3
            x = [100, 580, 1060]
            y = [10, 500]
            crop = 380
        }
        guard let source = UIImage(named: board)?.cgImage else { return nil }
        let rectangle = CGRect(x: x[index % columns], y: y[index / columns], width: crop, height: crop)
        guard let tile = source.cropping(to: rectangle) else { return nil }
        let image = UIImage(cgImage: tile)
        cache.setObject(image, forKey: baseID as NSString)
        return image
    }
}
