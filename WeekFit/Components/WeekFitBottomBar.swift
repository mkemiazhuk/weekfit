import SwiftUI

enum WeekFitTab: Hashable, CaseIterable {
    case today
    case coach
    // Highlights and Insights are intentionally unshipped — see docs/UnshippedFeatures.md
//    case highlights
//    case insights
    case meals
    case calendar

    /// Free core is Today only. Premium tabs stay visible but gated.
    var requiresPremium: Bool {
        switch self {
        case .today:
            return false
        case .coach, .meals, .calendar:
            return true
//        case .highlights, .insights:
//            return true
        }
    }

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
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Floating icon bar. Titles stay available to VoiceOver.
    private let barHeight: CGFloat = 52
    private let itemHeight: CGFloat = 44
    private let tabSpacing: CGFloat = 0
    private let barHorizontalPadding: CGFloat = 6
    private let activePillHeight: CGFloat = 40
    private let activePillHorizontalInset: CGFloat = 4
    private let iconPointSize: CGFloat = 20
    private let iconFrameHeight: CGFloat = 22

    private var barWidth: CGFloat {
        UIScreen.main.bounds.width - 44
    }

    private var itemWidth: CGFloat {
        let inner = barWidth - barHorizontalPadding * 2
        let gaps = CGFloat(max(WeekFitTab.allCases.count - 1, 0)) * tabSpacing
        return (inner - gaps) / CGFloat(WeekFitTab.allCases.count)
    }

    private var activePillWidth: CGFloat {
        max(56, itemWidth - activePillHorizontalInset * 2)
    }

    private var activeColor: Color {
        WeekFitTabBarTokens.activeForeground(isLight: palette.isLight)
    }

    private var inactiveColor: Color {
        let base = WeekFitTabBarTokens.inactiveForeground(isLight: palette.isLight)
        if !palette.isLight, colorSchemeContrast == .increased {
            return base.opacity(0.92)
        }
        return base
    }

    private var activePillFill: Color {
        WeekFitTabBarTokens.activeFill(isLight: palette.isLight)
    }

    private var tabSelectionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.28)
    }

    var body: some View {
        HStack(spacing: tabSpacing) {
            ForEach(WeekFitTab.allCases, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, barHorizontalPadding)
        .frame(width: barWidth, height: barHeight)
        .background {
            barChrome
        }
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabBar.main")
    }

    @ViewBuilder
    private var barChrome: some View {
        if palette.isLight {
            // Premium frosted island — bright milk glass, hairline rim, layered lift.
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.82))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.92),
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.softLight)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    WeekFitLightTokens.cardBorder.opacity(0.14)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.85
                        )
                }
                .shadow(color: Color.black.opacity(0.04), radius: 1, y: 0.5)
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
                .shadow(color: Color.black.opacity(0.04), radius: 18, y: 10)
        } else {
            // Quiet OLED island — sits in the night canvas, not a bright chrome slab.
            Capsule(style: .continuous)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.11).opacity(0.92))
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.6)
                }
                .shadow(color: Color.black.opacity(0.28), radius: 10, y: 5)
        }
    }

    private func tabItem(_ tab: WeekFitTab) -> some View {
        let active = selectedTab == tab

        return Button {
            handleTap(tab)
        } label: {
            ZStack {
                if active {
                    Capsule(style: .continuous)
                        .fill(activePillFill)
                        .matchedGeometryEffect(
                            id: "selectedTabBackground",
                            in: selectionNamespace
                        )
                        .frame(width: activePillWidth, height: activePillHeight)
                }

                Image(systemName: tab.icon)
                    .font(.system(size: iconPointSize, weight: active ? .semibold : .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(active ? activeColor : inactiveColor)
                    .frame(width: iconFrameHeight, height: iconFrameHeight)
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

        if let animation = tabSelectionAnimation {
            withAnimation(animation) {
                selectedTab = tab
            }
        } else {
            selectedTab = tab
        }
    }
}
