import SwiftUI

struct WeekFitRootView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel

    @StateObject private var planViewModel = PlanViewModel()
    @State private var selectedTab: WeekFitTab = .today
    @State private var todayResetTrigger = UUID()
    @State private var showContent = false

    var body: some View {
        ZStack(alignment: .bottom) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground

            Group {
                switch selectedTab {
                case .today:
                    TodayView(
                        authViewModel: authViewModel,
                        returnToTodayTrigger: todayResetTrigger,
                        onSelectTab: selectTab
                    )

                case .coach:
                    ExpertCoachViewV3(authViewModel: authViewModel)

                case .insights:
                    InsightsView(authViewModel: authViewModel)

                case .meals:
                    MealsView(
                        authViewModel: authViewModel,
                        nutritionResult: nutritionViewModel.nutritionResult
                    )

                case .calendar:
                    WeekPlannerView(
                        viewModel: planViewModel,
                        authViewModel: authViewModel
                    )
                }
            }
            .transition(
                .asymmetric(
                    insertion: .offset(y: 8).combined(with: .opacity),
                    removal: .opacity
                )
            )
            .animation(
                selectedTab == .coach
                    ? nil
                    : .interactiveSpring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12),
                value: selectedTab
            )

            WeekFitBottomBar(selectedTab: $selectedTab)
                .padding(.horizontal, 1)
                .background(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                        .offset(y: -7)
                }
                .shadow(color: Color.black.opacity(0.4), radius: 25, y: -10)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 120)
        }
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) {
                showContent = true
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            handleTabChange(from: oldValue, to: newValue)
        }
        .onChange(of: appSession.returnToTodayTrigger) { _, _ in
            returnToToday()
        }
    }

    private var ambientBackground: some View {
        Group {
            switch selectedTab {
            case .today:
                WeekFitTheme.todayAmbient
            case .coach:
                WeekFitTheme.coachAmbient
            case .insights:
                WeekFitTheme.todayAmbient
            case .meals:
                WeekFitTheme.mealsAmbient
            case .calendar:
                WeekFitTheme.planAmbient
            }
        }
        .ignoresSafeArea()
    }

    private func selectTab(_ tab: WeekFitTab) {
        guard selectedTab != tab else { return }

        if tab == .calendar {
            resetPlanDateToToday()
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

    private func handleTabChange(from oldValue: WeekFitTab, to newValue: WeekFitTab) {
        #if DEBUG
        if newValue == .coach {
            CoachRefreshDebug.log(
                "[CoachScreenLifecycle]",
                "CoachTab selected source=WeekFitRootView oldTab=\(oldValue)"
            )
        }
        #endif

        if newValue == .calendar {
            resetPlanDateToToday()
        }
    }

    private func returnToToday() {
        todayResetTrigger = UUID()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            selectedTab = .today
        }
    }

    private func resetPlanDateToToday() {
        let today = Date()
        guard !Calendar.current.isDate(planViewModel.selectedDate, inSameDayAs: today) else {
            return
        }

        planViewModel.selectedDate = today
    }
}
