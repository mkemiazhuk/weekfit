import SwiftUI

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

    private var isDisplayable: Bool {
        FoodImageQualityValidator.isDisplayableAsset(named: imageName)
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
            RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous)
                .fill(WeekFitTheme.whiteOpacity(0.04))

            assetOrFallback
        }
        .frame(width: frameSize, height: frameSize)
        .clipShape(RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: plateCornerRadius, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
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
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(
                    width: frameSize * contentScale,
                    height: frameSize * contentScale
                )
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
