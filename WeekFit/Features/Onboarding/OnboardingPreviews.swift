import SwiftUI

#if DEBUG
#Preview("Brand Splash") {
    OnboardingPromiseMark()
        .padding()
        .background(Color.black)
}

#Preview("Causality") {
    OnboardingCausalityStage()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Live Change") {
    OnboardingLiveChangeStage()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Health") {
    OnboardingHealthSignalsStage()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Today") {
    OnboardingTodayExperience()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Coach") {
    OnboardingCoachHero()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Ahead") {
    OnboardingAheadComposition()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Ready mark") {
    OnboardingBeginMark()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Flow v11") {
    FirstRunOnboardingView()
        .environmentObject(AppSessionState())
        .environmentObject(HealthManager())
        .environmentObject(AppLanguageManager())
}
#endif
