import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum PremiumAssetImageStyle {
    case quickLogThumbnail
    case activityThumbnail
    case mealCard
    case timelineAvatar
}

struct PremiumAssetImage: View {
    let imageName: String
    var style: PremiumAssetImageStyle = .quickLogThumbnail
    var accentColor: Color = WeekFitTheme.whiteOpacity(0.4)
    var fallbackSystemName: String = "fork.knife"

    @Environment(\.weekFitPalette) private var palette

    private var isDisplayable: Bool {
        let trimmed = imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        switch style {
        case .activityThumbnail:
            // Workout / recovery photos are opaque scene crops — don't apply
            // food-plate luminance gates that reject dark gym imagery (e.g. HIIT).
            #if canImport(UIKit)
            return UIImage(named: trimmed) != nil
            #else
            return true
            #endif
        case .quickLogThumbnail, .mealCard, .timelineAvatar:
            return FoodImageQualityValidator.isDisplayableAsset(named: trimmed)
        }
    }

    private var contentScale: CGFloat {
        switch style {
        case .quickLogThumbnail:
            return 0.68
        case .activityThumbnail:
            return 0.78
        case .mealCard:
            return 0.88
        case .timelineAvatar:
            return 0.72
        }
    }

    var body: some View {
        Group {
            switch style {
            case .timelineAvatar:
                avatarBody
            default:
                thumbnailBody
            }
        }
    }

    private var thumbnailBody: some View {
        ZStack {
            // Light: no grey tile — cutouts sit on the card surface.
            // Dark: keep a soft well so transparent assets stay readable.
            if !palette.isLight {
                RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous)
                    .fill(WeekFitTheme.whiteOpacity(0.04))
            } else if !isDisplayable {
                RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous)
                    .fill(WeekFitLightTokens.surfaceTertiary.opacity(0.55))
            }

            assetOrFallback
        }
        .frame(width: frameSize, height: frameSize)
        .clipShape(RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous))
        .overlay {
            if style == .activityThumbnail && isDisplayable {
                RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous)
                    .stroke(
                        palette.isLight
                            ? Color.black.opacity(0.07)
                            : WeekFitTheme.whiteOpacity(0.08),
                        lineWidth: 1
                    )
            } else if !palette.isLight || !isDisplayable {
                RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous)
                    .stroke(
                        palette.isLight
                            ? WeekFitLightTokens.divider.opacity(0.35)
                            : WeekFitTheme.whiteOpacity(0.045),
                        lineWidth: 1
                    )
            }
        }
    }

    private var avatarBody: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.08))

            assetOrFallback
        }
        .frame(width: frameSize, height: frameSize)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var assetOrFallback: some View {
        if isDisplayable {
            switch style {
            case .activityThumbnail:
                // Opaque workout/recovery photos: edge-to-edge so Light sheets
                // aren't dominated by empty pearl margins around landscape crops.
                Image(imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: frameSize, height: frameSize)
                    .clipped()
            default:
                Image(imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(
                        width: frameSize * contentScale,
                        height: frameSize * contentScale
                    )
            }
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: fallbackIconSize, weight: .semibold))
                .foregroundStyle(accentColor)
        }
    }

    private var frameSize: CGFloat {
        switch style {
        case .quickLogThumbnail:
            return QuickLogRowMetrics.imageSize
        case .activityThumbnail:
            return QuickActionSheetDesign.Row.imageSize
        case .mealCard:
            return 64
        case .timelineAvatar:
            return 28
        }
    }

    private var plateCornerRadius: CGFloat {
        switch style {
        case .quickLogThumbnail:
            return QuickLogRowMetrics.imageCornerRadius
        case .activityThumbnail:
            return QuickActionSheetDesign.Row.imageCornerRadius
        case .mealCard:
            return 12
        case .timelineAvatar:
            return 14
        }
    }

    private var fallbackIconSize: CGFloat {
        switch style {
        case .quickLogThumbnail:
            return 21
        case .activityThumbnail:
            return 19
        case .mealCard:
            return 14
        case .timelineAvatar:
            return 12
        }
    }
}
