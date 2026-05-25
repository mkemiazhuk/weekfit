import SwiftUI

enum WeekFitTab: Hashable {
    case today
    case coach
    case meals
    case calendar
}

struct WeekFitBottomBar: View {

    @Binding var selectedTab: WeekFitTab
    var onCalendarTap: (() -> Void)? = nil

    @Namespace private var selectionNamespace

    private let barWidth: CGFloat = 340
    private let barHeight: CGFloat = 58
    private let itemWidth: CGFloat = 80
    private let itemHeight: CGFloat = 46

    private var activeColor: Color {
        WeekFitTheme.primaryText.opacity(0.96)
    }

    private var inactiveColor: Color {
        WeekFitTheme.secondaryText.opacity(0.52)
    }

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.today, icon: "figure.mind.and.body", title: "Today")
            tabItem(.meals, icon: "fork.knife", title: "Meals")
            tabItem(.coach, icon: "brain.head.profile", title: "Coach")
            tabItem(.calendar, icon: "calendar", title: "Plan")
        }
        .frame(width: barWidth, height: barHeight)
        .padding(.horizontal, 5)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.075),
                                    Color.white.opacity(0.035),
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.16),
                                    Color.white.opacity(0.045),
                                    Color.black.opacity(0.18)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.30), radius: 24, x: 0, y: 14)
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 1)
        }
        .padding(.bottom, 14)
        .accessibilityElement(children: .contain)
    }

    private func tabItem(
        _ tab: WeekFitTab,
        icon: String,
        title: String
    ) -> some View {

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
                                    Color.white.opacity(0.145),
                                    Color.white.opacity(0.075)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(id: "selectedTabBackground", in: selectionNamespace)
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.105), lineWidth: 1)
                        }
                        .shadow(color: Color.white.opacity(0.045), radius: 8, x: 0, y: -2)
                        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 5)
                        .frame(width: 68, height: 44)
                }

                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: active ? 18 : 17, weight: active ? .semibold : .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(active ? activeColor : inactiveColor)
                        .frame(height: 20)
                        .scaleEffect(active ? 1.04 : 1.0)

                    Text(title)
                        .font(.system(size: 11.4, weight: active ? .semibold : .medium))
                        .tracking(active ? 0.1 : 0)
                        .foregroundStyle(active ? activeColor : inactiveColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(width: itemWidth, height: itemHeight)
                .animation(.spring(response: 0.32, dampingFraction: 0.86), value: active)
            }
            .frame(width: itemWidth, height: itemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    private func handleTap(_ tab: WeekFitTab) {
        // Если таббар просит переключиться на тот же экран, ничего не делаем
        guard selectedTab != tab else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Переключаем вкладку реактивно с анимацией matchedGeometryEffect для капсулы
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82, blendDuration: 0.08)) {
            selectedTab = tab
        }

        // Если это календарь, дополнительно вызываем кастомный колбэк (например, для сброса стейта редактирования)
        if tab == .calendar {
            onCalendarTap?()
        }
    }
}
