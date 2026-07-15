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
        case sleep
        case workout

        var iconColor: Color {
            switch self {
            case .recovery:
                Color(red: 0.54, green: 0.88, blue: 0.65)
            case .sleep:
                Color(red: 0.50, green: 0.36, blue: 0.88)
            case .workout:
                Color(red: 0.96, green: 0.56, blue: 0.26)
            }
        }

        var systemImage: String {
            switch self {
            case .recovery:
                "heart.fill"
            case .sleep:
                "moon.fill"
            case .workout:
                "figure.mind.and.body"
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
                id: "sleep",
                accent: .sleep,
                title: WeekFitLocalizedString("login.card.sleep.title"),
                value: WeekFitLocalizedString("login.card.sleep.value"),
                subtitle: WeekFitLocalizedString("login.card.sleep.subtitle"),
                accessory: .bars,
                prominence: .supporting(1)
            ),
            LoginInsightCardData(
                id: "workout",
                accent: .workout,
                title: WeekFitLocalizedString("login.card.workout.title"),
                value: WeekFitLocalizedString("login.card.workout.value"),
                subtitle: WeekFitLocalizedString("login.card.workout.subtitle"),
                accessory: .spark,
                prominence: .supporting(2)
            )
        ]
    }
}
