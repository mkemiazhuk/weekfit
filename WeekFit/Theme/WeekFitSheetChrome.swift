import SwiftUI

extension View {
    func weekFitSheetChrome(cornerRadius: CGFloat? = nil) -> some View {
        self
            // Opaque background avoids iOS 16–17 presentation hangs with
            // NavigationStack-in-sheet and nested sheets (clear chrome was a known trigger).
            .presentationBackground(WeekFitTheme.backgroundColor)
            .presentationCornerRadius(cornerRadius)
            .preferredColorScheme(.dark)
            .environment(\.weekFitPalette, WeekFitPaletteStore.current)
    }
}
