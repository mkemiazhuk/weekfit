import SwiftUI

/// Light-only visual system for Nutrition Details (reference-matched density).
/// Dark Appearance continues to use legacy chrome and must not change.
enum NutritionDetailsDesign {

    // MARK: - Canvas

    /// Warm cream aligned with WeekFitLightTokens.backgroundPrimary (#F0EDE5)
    static let canvas = Color(red: 0.941, green: 0.929, blue: 0.898)

    /// Warm white elevated cards aligned with WeekFitLightTokens.surfaceCard (#FFFCF7)
    static let cardSurface = Color(red: 1.000, green: 0.988, blue: 0.969)

    static let divider = Color(red: 0.835, green: 0.816, blue: 0.780)

    // MARK: - Metric tints

    static let waterTint = Color(red: 0.925, green: 0.949, blue: 0.980)
    static let caloriesTint = Color(red: 1.000, green: 0.957, blue: 0.922)
    static let noticeTint = Color(red: 0.965, green: 0.949, blue: 0.922)

    static let waterAccent = WeekFitLightTokens.water
    static let nutritionAccent = WeekFitLightTokens.nutrition

    static let protein = WeekFitLightTokens.protein
    static let carbs = WeekFitLightTokens.carbs
    static let fats = WeekFitLightTokens.fats
    static let fiber = WeekFitLightTokens.fiber

    // MARK: - Layout (compact — matches reference viewport density)

    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 10
    static let largeCorner: CGFloat = 22
    static let metricCorner: CGFloat = 18
    static let noticeCorner: CGFloat = 16
    static let weekPillCorner: CGFloat = 14

    static let qualityRingSize: CGFloat = 58
    static let qualityRingStroke: CGFloat = 4.5
    static let macroRingSize: CGFloat = 44
    static let macroRingStroke: CGFloat = 3.5
    static let cardPadding: CGFloat = 12
    static let metricCardPadding: CGFloat = 11

    /// Reading layout for the Nutrition Details screen. Shared light chrome
    /// constants above stay untouched for Activity and Recovery.
    enum Reading {
        static let horizontalPadding: CGFloat = 18
        static let cardPadding: CGFloat = 18
        static let sectionSpacing: CGFloat = 11
        static let corner: CGFloat = 20
        static let barHeight: CGFloat = 5
        static let mealPhoto: CGFloat = 50
    }

    // MARK: - Typography

    enum Typography {
        static let screenTitle: Font = .system(size: 28, weight: .bold, design: .default)
        static let screenSubtitle: Font = .system(size: 14, weight: .regular, design: .default)
        static let insight: Font = .system(size: 16, weight: .semibold, design: .default)
        static let sectionTitle: Font = .system(size: 15, weight: .semibold, design: .default)
        static let metricValue: Font = .system(size: 17, weight: .bold, design: .rounded)
        static let metricSecondary: Font = .system(size: 11, weight: .regular, design: .default)
        static let metricLabel: Font = .system(size: 11, weight: .semibold, design: .rounded)
        static let eyebrow: Font = .system(size: 9, weight: .bold, design: .rounded)
        static let score: Font = .system(size: 20, weight: .bold, design: .rounded)
        static let scoreDenom: Font = .system(size: 8, weight: .bold, design: .rounded)
        static let macroPercent: Font = .system(size: 11, weight: .bold, design: .rounded)
        static let macroTitle: Font = .system(size: 11, weight: .semibold, design: .rounded)
        static let macroValue: Font = .system(size: 10, weight: .regular, design: .rounded)
        static let mealTitle: Font = .system(size: 14, weight: .semibold, design: .default)
        static let mealMeta: Font = .system(size: 11, weight: .regular, design: .rounded)
        static let notice: Font = .system(size: 11.5, weight: .regular, design: .default)
        static let statusPill: Font = .system(size: 10, weight: .semibold, design: .rounded)
        static let weekDay: Font = .system(size: 10, weight: .semibold, design: .rounded)
        static let weekDate: Font = .system(size: 13, weight: .bold, design: .rounded)
    }

    // MARK: - Shadows / borders

    static let cardBorderOpacity: Double = 0.045
    static let cardShadowAmbient = Color.black.opacity(0.040)
    static let cardShadowContact = Color.black.opacity(0.022)
}

// MARK: - Card container

struct NutritionDetailsCard<Content: View>: View {
    @Environment(\.weekFitPalette) private var palette

    var cornerRadius: CGFloat = NutritionDetailsDesign.Reading.corner
    var fill: Color? = nil
    var borderOpacity: Double = NutritionDetailsDesign.cardBorderOpacity
    var padding: CGFloat = NutritionDetailsDesign.Reading.cardPadding
    var edgeInsets: EdgeInsets? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let resolvedFill = fill ?? (palette.isLight ? NutritionDetailsDesign.cardSurface : palette.cardSurface)
        let border = palette.isLight
            ? WeekFitLightTokens.cardBorder.opacity(WeekFitLightTokens.cardBorderStrokeOpacity)
            : Color.white.opacity(0.08)
        let insets = edgeInsets ?? EdgeInsets(
            top: padding,
            leading: padding,
            bottom: padding,
            trailing: padding
        )

        content()
            .padding(insets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(resolvedFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(border, lineWidth: 0.7)
                    }
                    .shadow(
                        color: palette.isLight
                            ? Color.black.opacity(WeekFitLightTokens.cardContactShadowOpacity)
                            : .clear,
                        radius: palette.isLight ? 8 : 0,
                        y: palette.isLight ? 3 : 0
                    )
            }
    }
}

struct NutritionReadingFont: ViewModifier {
    var weight: Font.Weight
    var design: Font.Design
    @ScaledMetric var size: CGFloat

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo: Font.TextStyle) {
        self.weight = weight
        self.design = design
        _size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func nutritionReading(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo style: Font.TextStyle = .body
    ) -> some View {
        modifier(
            NutritionReadingFont(
                size: size,
                weight: weight,
                design: design,
                relativeTo: style
            )
        )
    }
}

// MARK: - Shared nutrition accents (used outside details too)

enum NutritionStyle {
    static var screenBackground: Color {
        WeekFitPaletteStore.current.isLight
            ? NutritionDetailsDesign.canvas
            : WeekFitPaletteStore.current.appScreenBackground
    }

    static var nutritionColor: Color {
        WeekFitProgressRingColor.nutrition
    }

    static var proteinColor: Color {
        WeekFitTheme.accent(Color(red: 0.55, green: 0.40, blue: 0.95))
    }

    static var carbsColor: Color {
        WeekFitTheme.accent(Color(red: 1.00, green: 0.55, blue: 0.16))
    }

    static var fatColor: Color {
        WeekFitTheme.accent(Color(red: 1.00, green: 0.22, blue: 0.43))
    }

    static var fiberColor: Color {
        WeekFitTheme.accent(Color(red: 0.16, green: 0.80, blue: 0.43))
    }
}
