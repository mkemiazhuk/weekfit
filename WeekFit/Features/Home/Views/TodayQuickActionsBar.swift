import SwiftUI
import UIKit

struct TodayQuickActionItem: Identifiable {
    let id: String
    let icon: String
    let label: String
    let accessibilityLabel: String
    let color: Color
    let isEmphasized: Bool
    let liveIndicatorColor: Color?
    let toastMessage: String?
    let accessibilityIdentifier: String
    let action: () -> Void
}

enum TodayQuickActionMetrics {
    /// Matches `TodayCardTypography.quickActionLabel` before Dynamic Type scaling.
    static let labelBase: CGFloat = 16

    /// Card content width on the narrowest supported phone (375pt: SE 3, 12 mini, 13 mini).
    /// Screen inset 20×2 plus the quick-actions card padding 16×2.
    static let narrowestCardContentWidth: CGFloat = 303

    static func labelPointSize(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: contentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: .subheadline)
            .scaledValue(for: labelBase, compatibleWith: traits)
    }

    static func labelWidth(_ text: String, dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let pointSize = labelPointSize(for: dynamicTypeSize)
        let base = UIFont.systemFont(ofSize: pointSize, weight: .medium)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let font = UIFont(descriptor: descriptor, size: pointSize)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    /// True when every caption fits one column with a small gap so `.lineLimit(1)` does not ellipsize.
    static func columnsFit(
        labels: [String],
        contentWidth: CGFloat,
        dynamicTypeSize: DynamicTypeSize
    ) -> Bool {
        guard !labels.isEmpty, contentWidth > 1 else { return true }
        let column = contentWidth / CGFloat(labels.count)
        return labels.allSatisfy { labelWidth($0, dynamicTypeSize: dynamicTypeSize) <= column - 2 }
    }

    static func contentSizeCategory(_ size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

struct TodayQuickActionsBar: View {
    let actions: [TodayQuickActionItem]
    let isLight: Bool
    let textPrimary: Color

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var measuredWidth: CGFloat = 0

    private var contentWidth: CGFloat {
        measuredWidth > 1 ? measuredWidth : TodayQuickActionMetrics.narrowestCardContentWidth
    }

    private var usesColumns: Bool {
        TodayQuickActionMetrics.columnsFit(
            labels: actions.map(\.label),
            contentWidth: contentWidth,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        Group {
            if usesColumns {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(actions) { item in
                        actionButton(item, axis: .vertical)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(actions) { item in
                        actionButton(item, axis: .horizontal)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            usesColumns
                ? "today.quickActions.layout.columns"
                : "today.quickActions.layout.stacked"
        )
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { _, newWidth in
            if abs(newWidth - measuredWidth) > 0.5 {
                measuredWidth = newWidth
            }
        }
    }

    private func actionButton(_ item: TodayQuickActionItem, axis: Axis) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            item.action()
        } label: {
            Group {
                if axis == .vertical {
                    VStack(spacing: 8) {
                        iconWell(item)
                        caption(item, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                } else {
                    HStack(spacing: 12) {
                        iconWell(item)
                        caption(item, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(TodayQuickActionPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityIdentifier(item.accessibilityIdentifier)
        .accessibilityAddTraits(.isButton)
    }

    private func caption(_ item: TodayQuickActionItem, alignment: TextAlignment) -> some View {
        Text(verbatim: item.label)
            .font(.system(
                size: TodayQuickActionMetrics.labelPointSize(for: dynamicTypeSize),
                weight: .medium,
                design: .rounded
            ))
            .foregroundStyle(
                isLight
                    ? textPrimary
                    : textPrimary.opacity(item.isEmphasized ? 0.94 : 0.88)
            )
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(alignment)
    }

    private func iconWell(_ item: TodayQuickActionItem) -> some View {
        let iconForeground = isLight
            ? item.color
            : item.color.opacity(item.isEmphasized ? 0.94 : 0.88)

        return ZStack(alignment: .top) {
            lens(color: item.color, isEmphasized: item.isEmphasized)
                .frame(width: 52, height: 52)

            Image(systemName: item.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconForeground)
                .offset(y: iconOpticalYOffset(item.icon))
                .frame(width: 52, height: 52)

            if let liveIndicatorColor = item.liveIndicatorColor {
                Circle()
                    .fill(liveIndicatorColor)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(Color.black.opacity(0.28), lineWidth: 1))
                    .offset(x: 14, y: -12)
            }

            if let toastMessage = item.toastMessage {
                Text(toastMessage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(item.color.opacity(0.92))
                    .clipShape(Capsule())
                    .offset(y: -32)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
    }

    private func lens(color: Color, isEmphasized: Bool) -> some View {
        let fillOpacity = isEmphasized ? (isLight ? 0.24 : 0.17) : (isLight ? 0.18 : 0.11)
        let strokeOpacity = isEmphasized ? (isLight ? 0.40 : 0.22) : (isLight ? 0.30 : 0.15)
        return Circle()
            .fill(color.opacity(fillOpacity))
            .overlay(
                Circle()
                    .stroke(color.opacity(strokeOpacity), lineWidth: isEmphasized ? 1.1 : 1)
            )
    }

    private func iconOpticalYOffset(_ systemName: String) -> CGFloat {
        switch systemName {
        case "fork.knife", "takeoutbag.and.cup.and.straw.fill":
            return 0.5
        case "play.circle.fill", "stop.circle.fill":
            return 0
        default:
            return 0
        }
    }
}

private struct TodayQuickActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(.spring(response: 0.20, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
