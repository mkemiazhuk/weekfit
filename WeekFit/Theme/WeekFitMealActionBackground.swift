import SwiftUI

struct WeekFitMealActionBackground: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.135),
                                color.opacity(0.085)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Capsule()
                            .stroke(color.opacity(0.17), lineWidth: 1)
                    }
            }
    }
}

extension View {
    func weekFitMealActionBackground(
        _ color: Color = WeekFitTheme.meal
    ) -> some View {
        modifier(WeekFitMealActionBackground(color: color))
    }
}
