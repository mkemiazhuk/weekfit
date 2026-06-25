import SwiftUI

struct WeekFitIconBadge: View {

    enum Size {
        case sm
        case md
        case lg

        var dimension: CGFloat {
            switch self {
            case .sm: return 36
            case .md: return 40
            case .lg: return 44
            }
        }

        var iconFontSize: CGFloat {
            switch self {
            case .sm: return 16
            case .md: return 17
            case .lg: return 16
            }
        }

        var roundedRectCornerRadius: CGFloat {
            switch self {
            case .sm: return 14
            case .md: return 15
            case .lg: return 16
            }
        }
    }

    enum BadgeShape {
        case circle
        case roundedRect
    }

    let systemName: String
    let color: Color
    var size: Size = .md
    var shape: BadgeShape = .circle
    var backgroundOpacity: Double = 0.12
    var foregroundOpacity: Double = 1.0
    var strokeOpacity: Double = 0
    var strokeWidth: CGFloat = 1
    var fillColor: Color?
    var strokeColor: Color?
    var iconColor: Color?
    var opticalYOffset: CGFloat?

    var body: some View {
        ZStack {
            badgeBackground

            Image(systemName: systemName)
                .font(.system(size: size.iconFontSize, weight: .semibold))
                .foregroundStyle(resolvedIconColor)
                .offset(y: resolvedOpticalYOffset)
        }
        .frame(width: size.dimension, height: size.dimension)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badgeBackground: some View {
        switch shape {
        case .circle:
            Circle()
                .fill(resolvedFillColor)
                .overlay {
                    if strokeOpacity > 0 {
                        Circle()
                            .stroke(resolvedStrokeColor, lineWidth: strokeWidth)
                    }
                }
        case .roundedRect:
            RoundedRectangle(cornerRadius: size.roundedRectCornerRadius, style: .continuous)
                .fill(resolvedFillColor)
                .overlay {
                    if strokeOpacity > 0 {
                        RoundedRectangle(cornerRadius: size.roundedRectCornerRadius, style: .continuous)
                            .stroke(resolvedStrokeColor, lineWidth: strokeWidth)
                    }
                }
        }
    }

    private var resolvedFillColor: Color {
        fillColor ?? color.opacity(backgroundOpacity)
    }

    private var resolvedStrokeColor: Color {
        strokeColor ?? color.opacity(strokeOpacity)
    }

    private var resolvedIconColor: Color {
        iconColor ?? color.opacity(foregroundOpacity)
    }

    private var resolvedOpticalYOffset: CGFloat {
        if let opticalYOffset {
            return opticalYOffset
        }
        return systemName.hasPrefix("figure.") ? -0.5 : 0
    }
}
