import SwiftUI

enum WeekFitTab: Hashable, CaseIterable {
    case today
    case coach
    // Highlights and Insights are intentionally unshipped — see docs/UnshippedFeatures.md
//    case highlights
//    case insights
    case meals
    case calendar

    var icon: String {
        switch self {
        case .today: return "figure.mind.and.body"
        case .coach: return "brain.head.profile"
//        case .highlights: return "sparkles"
//        case .insights: return "chart.line.uptrend.xyaxis"
        case .meals: return "fork.knife"
        case .calendar: return "calendar"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .today: return AppText.Common.Tab.today
        case .coach: return AppText.Common.Tab.coach
//        case .highlights: return AppText.Common.Tab.highlights
//        case .insights: return "Insights"
        case .meals: return AppText.Common.Tab.meals
        case .calendar: return AppText.Common.Tab.plan
        }
    }
}

struct WeekFitBottomBar: View {

    @Binding var selectedTab: WeekFitTab

    @Namespace private var selectionNamespace
    @Environment(\.weekFitPalette) private var palette

    private let barHeight: CGFloat = 52
    private let itemHeight: CGFloat = 42

    private var barWidth: CGFloat {
        min(UIScreen.main.bounds.width - 20, 370)
    }

    private var itemWidth: CGFloat {
        (barWidth - 10) / CGFloat(WeekFitTab.allCases.count)
    }

    private var activePillWidth: CGFloat {
        min(66, itemWidth - 6)
    }

    private var activeColor: Color {
        palette.textPrimary.opacity(0.94)
    }

    private var inactiveColor: Color {
        palette.textSecondary.opacity(0.52)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WeekFitTab.allCases, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .frame(width: barWidth, height: barHeight)
        .padding(.horizontal, 5)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.15, blue: 0.17),
                            Color(red: 0.09, green: 0.10, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    WeekFitTheme.whiteOpacity(0.08),
                                    WeekFitTheme.whiteOpacity(0.03),
                                    Color.black.opacity(0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: Color.black.opacity(0.30),
                    radius: 18,
                    x: 0,
                    y: 10
                )
        }
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabBar.main")
    }

    private func tabItem(_ tab: WeekFitTab) -> some View {
        let active = selectedTab == tab

        return Button {
            handleTap(tab)
        } label: {
            ZStack {
                if active {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    WeekFitTheme.whiteOpacity(0.100),
                                    WeekFitTheme.whiteOpacity(0.045)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(
                            id: "selectedTabBackground",
                            in: selectionNamespace
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    WeekFitTheme.whiteOpacity(0.065),
                                    lineWidth: 1
                                )
                        }
                        .shadow(
                            color: WeekFitTheme.whiteOpacity(0.030),
                            radius: 6,
                            x: 0,
                            y: -1
                        )
                        .shadow(
                            color: Color.black.opacity(0.12),
                            radius: 6,
                            x: 0,
                            y: 4
                        )
                        .frame(width: activePillWidth, height: 40)
                }

                VStack(spacing: 3) {
                    Image(systemName: tab.icon)
                        .font(
                            .system(
                                size: active ? 17 : 16,
                                weight: active ? .semibold : .medium
                            )
                        )
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(active ? activeColor : inactiveColor)
                        .frame(height: 19)
                        .scaleEffect(active ? 1.03 : 1.0)

                    Text(tab.title)
                        .font(
                            .system(
                                size: 11.2,
                                weight: active ? .semibold : .medium
                            )
                        )
                        .tracking(active ? 0.08 : 0)
                        .foregroundStyle(active ? activeColor : inactiveColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(width: itemWidth, height: itemHeight)
                .animation(
                    .spring(response: 0.32, dampingFraction: 0.86),
                    value: active
                )
            }
            .frame(width: itemWidth, height: itemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(tabAccessibilityName(tab))")
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    private func tabAccessibilityName(_ tab: WeekFitTab) -> String {
        switch tab {
        case .today: return "today"
        case .coach: return "coach"
        case .meals: return "meals"
        case .calendar: return "plan"
        }
    }

    private func handleTap(_ tab: WeekFitTab) {
        guard selectedTab != tab else { return }

        #if DEBUG
        TabSwitchDiagnostics.markSwitchStarted()
        #endif

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if tab == .coach {
            selectedTab = tab
            return
        }

        withAnimation(
            .spring(
                response: 0.36,
                dampingFraction: 0.82,
                blendDuration: 0.08
            )
        ) {
            selectedTab = tab
        }

    }
}
