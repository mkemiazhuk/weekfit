import SwiftUI

extension View {
    /// Opaque sheet chrome. Pass `background` for quick-action sheets that need a
    /// deeper Light canvas than the main ivory page (food / drinks / activity).
    func weekFitSheetChrome(
        cornerRadius: CGFloat? = nil,
        background: Color? = nil
    ) -> some View {
        modifier(WeekFitSheetChromeModifier(cornerRadius: cornerRadius, background: background))
    }
}

/// Reads canvas from `@Environment(\.weekFitPalette)` so sheet chrome never paints
/// a stale `WeekFitTheme` / store snapshot after background → foreground.
private struct WeekFitSheetChromeModifier: ViewModifier {
    let cornerRadius: CGFloat?
    let background: Color?
    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        content
            // Opaque background avoids iOS 16–17 presentation hangs with
            // NavigationStack-in-sheet and nested sheets (clear chrome was a known trigger).
            .presentationBackground(background ?? palette.appScreenBackground)
            .presentationCornerRadius(cornerRadius)
    }
}
