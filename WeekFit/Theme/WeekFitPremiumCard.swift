import SwiftUI

struct WeekFitPremiumCardModifier: ViewModifier {

    let accent: Color
    var cornerRadius: CGFloat = 20
    var featured: Bool = true

    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        let softenedAccent = palette.accent(accent)
        let featuredGlow = palette.accentOpacity(featured ? 0.05 : 0.025)

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.cardBackground.opacity(featured ? 0.94 : 0.88),
                                WeekFitTheme.whiteOpacity(featured ? 0.024 : 0.014)
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
                                softenedAccent.opacity(palette.accentOpacity(featured ? 0.16 : 0.10)),
                                palette.borderSoft,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: softenedAccent.opacity(Double(featuredGlow)),
                radius: featured ? 12 : 6,
                y: featured ? 5 : 2
            )
            .shadow(
                color: Color.black.opacity(Double(palette.cardShadowOpacity * (featured ? 0.36 : 0.21))),
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
