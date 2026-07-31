import SwiftUI

enum QuickActionSheetDesign {
    enum Color {
        @MainActor
        static var sheetBackground: SwiftUI.Color { WeekFitTheme.backgroundColor }
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let listRowSpacing: CGFloat = 8
        static let listBottomPadding: CGFloat = 20
        static let sheetCornerRadius: CGFloat = 34
        static let segmentedTopPadding: CGFloat = 4
        static let segmentedBottomPadding: CGFloat = 8
    }

    enum Row {
        static let height: CGFloat = 76
        static let horizontalPadding: CGFloat = 12
        static let imageSize: CGFloat = 64
        static let imageCornerRadius: CGFloat = 15
        static let cardCornerRadius: CGFloat = 20
        static let actionButtonSize: CGFloat = 36
        static let actionExpandedWidth: CGFloat = 88
        static let contentSpacing: CGFloat = 12
    }

    enum Typography {
        static let headerTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let headerSubtitle = Font.system(size: 12, weight: .medium, design: .rounded)
        static let rowTitle = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let rowSubtitle = Font.system(size: 12, weight: .medium, design: .rounded)
        static let rowMeta = Font.system(size: 11, weight: .medium, design: .rounded)
        static let segmentLabel = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let segmentBadge = Font.system(size: 10, weight: .bold, design: .rounded)
        static let emptyTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let emptyMessage = Font.system(size: 12, weight: .medium, design: .rounded)
        static let rowBadge = Font.system(size: 9, weight: .bold, design: .rounded)
    }

    enum SegmentedControl {
        static let height: CGFloat = 32
        static let containerPadding: CGFloat = 3
    }
}

/// Reserved anchor for future Coach recommendations inside quick-action sheets.
struct QuickActionCoachRecommendationSlot: View {
    var body: some View {
        Color.clear
            .frame(height: 0)
            .accessibilityHidden(true)
    }
}

struct QuickActionSheetSegment: Identifiable, Hashable {
    let id: String
    let title: String
    let badgeCount: Int

    init(id: String, title: String, badgeCount: Int = 0) {
        self.id = id
        self.title = title
        self.badgeCount = badgeCount
    }
}

struct QuickActionSheetSegmentedControl: View {
    let segments: [QuickActionSheetSegment]
    @Binding var selection: String

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments) { segment in
                let isSelected = selection == segment.id

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selection = segment.id
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(segment.title)
                            .font(QuickActionSheetDesign.Typography.segmentLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if segment.badgeCount > 0 {
                            Text("\(segment.badgeCount)")
                                .font(QuickActionSheetDesign.Typography.segmentBadge)
                                .foregroundStyle(
                                    isSelected
                                        ? (palette.isLight ? WeekFitTheme.primaryText.opacity(0.70) : .black.opacity(0.68))
                                        : WeekFitTheme.secondaryText.opacity(0.55)
                                )
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .fill(
                                            isSelected
                                                ? (palette.isLight
                                                   ? WeekFitLightTokens.shadowContact.opacity(0.08)
                                                   : .white.opacity(0.68))
                                                : (palette.isLight
                                                   ? WeekFitLightTokens.shadowContact.opacity(0.05)
                                                   : .white.opacity(0.06))
                                        )
                                }
                        }
                    }
                    .foregroundStyle(isSelected ? (palette.isLight ? WeekFitTheme.primaryText : .white.opacity(0.94)) : WeekFitTheme.secondaryText.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: QuickActionSheetDesign.SegmentedControl.height)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: palette.isLight
                                            ? [
                                                Color.white.opacity(0.98),
                                                Color.white.opacity(0.88)
                                            ]
                                            : [
                                                WeekFitTheme.whiteOpacity(0.13),
                                                WeekFitTheme.whiteOpacity(0.07)
                                            ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            palette.isLight
                                                ? WeekFitLightTokens.shadowContact.opacity(0.08)
                                                : WeekFitTheme.whiteOpacity(0.10),
                                            lineWidth: 1
                                        )
                                }
                                .shadow(
                                    color: palette.isLight
                                        ? WeekFitLightTokens.shadowAmbient.opacity(0.08)
                                        : .clear,
                                    radius: 6,
                                    y: 2
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(QuickActionSheetDesign.SegmentedControl.containerPadding)
        .background {
            Capsule()
                .fill(palette.isLight
                      ? WeekFitLightTokens.shadowContact.opacity(0.05)
                      : WeekFitTheme.whiteOpacity(0.034))
        }
        .overlay {
            Capsule()
                .stroke(
                    palette.isLight
                        ? WeekFitLightTokens.shadowContact.opacity(0.06)
                        : WeekFitTheme.whiteOpacity(0.045),
                    lineWidth: 1
                )
        }
    }
}
