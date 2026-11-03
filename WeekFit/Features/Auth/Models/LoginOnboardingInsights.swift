import SwiftUI

struct LoginInsightCardData: Identifiable, Equatable {
    enum Prominence: Equatable {
        case primary
        case supporting(Int)
    }

    enum Accessory: Equatable {
        case ecg
        case bars
        case spark
    }

    enum Accent: Equatable {
        case recovery
        case meal
        case activity

        var iconColor: Color {
            switch self {
            case .recovery:
                Color(red: 0.54, green: 0.88, blue: 0.65)
            case .meal:
                WeekFitSemanticMetricTokens.nutrition
            case .activity:
                WeekFitSemanticMetricTokens.activity
            }
        }

        var systemImage: String {
            switch self {
            case .recovery:
                "heart.fill"
            case .meal:
                "fork.knife"
            case .activity:
                "figure.run"
            }
        }
    }

    let id: String
    let accent: Accent
    let title: String
    let value: String
    let subtitle: String
    let accessory: Accessory
    let prominence: Prominence
}

@MainActor
enum LoginOnboardingInsights {

    /// Illustrative ambient cards. Signed-out only — never HealthKit/cache values.
    static var loginScreenCards: [LoginInsightCardData] {
        [
            LoginInsightCardData(
                id: "recovery",
                accent: .recovery,
                title: WeekFitLocalizedString("login.card.recovery.title"),
                value: WeekFitLocalizedString("login.card.recovery.value"),
                subtitle: WeekFitLocalizedString("login.card.recovery.subtitle"),
                accessory: .ecg,
                prominence: .primary
            ),
            LoginInsightCardData(
                id: "meal",
                accent: .meal,
                title: WeekFitLocalizedString("login.card.meal.title"),
                value: WeekFitLocalizedString("login.card.meal.value"),
                subtitle: WeekFitLocalizedString("login.card.meal.subtitle"),
                accessory: .bars,
                prominence: .supporting(1)
            ),
            LoginInsightCardData(
                id: "activity",
                accent: .activity,
                title: WeekFitLocalizedString("login.card.activity.title"),
                value: WeekFitLocalizedString("login.card.activity.value"),
                subtitle: WeekFitLocalizedString("login.card.activity.subtitle"),
                accessory: .spark,
                prominence: .supporting(2)
            )
        ]
    }
}
