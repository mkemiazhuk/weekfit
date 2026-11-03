import SwiftUI

#if DEBUG
#Preview("Welcome") {
    OnboardingWelcomeView()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
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

#Preview("Maya call") {
    OnboardingMayaCallStage()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Adaptation") {
    OnboardingAdaptationStage()
        .padding()
        .background(WeekFitTheme.ambientCanvasBackground)
}

#Preview("Nutrition showcase") {
    OnboardingNutritionShowcaseView()
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
