import SwiftUI

struct WeekFitPremiumCardModifier: ViewModifier {

    let accent: Color
    var cornerRadius: CGFloat = 20
    var featured: Bool = true

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WeekFitTheme.cardBackground.opacity(featured ? 0.94 : 0.88),
                                Color.white.opacity(featured ? 0.024 : 0.014)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accent.opacity(featured ? 0.16 : 0.10),
                                WeekFitTheme.borderSoft,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: accent.opacity(featured ? 0.05 : 0.025),
                radius: featured ? 12 : 6,
                y: featured ? 5 : 2
            )
            .shadow(
                color: Color.black.opacity(featured ? 0.10 : 0.06),
                radius: featured ? 8 : 4,
                y: featured ? 3 : 2
            )
    }
}

extension View {

    func weekFitPremiumCard(
        accent: Color,
        cornerRadius: CGFloat = 20,
        featured: Bool = true
    ) -> some View {
        modifier(
            WeekFitPremiumCardModifier(
                accent: accent,
                cornerRadius: cornerRadius,
                featured: featured
            )
        )
    }
}
