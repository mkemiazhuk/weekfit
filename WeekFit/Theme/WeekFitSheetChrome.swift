import SwiftUI

extension View {
    func weekFitSheetChrome(cornerRadius: CGFloat? = nil) -> some View {
        self
            // Opaque background avoids iOS 16–17 presentation hangs with
            // NavigationStack-in-sheet and nested sheets (clear chrome was a known trigger).
            .presentationBackground(WeekFitTheme.appScreenBackground)
            .presentationCornerRadius(cornerRadius)
            // Inherit preferredColorScheme + weekFitPalette from the window so theme
            // switches stay atomic (no store/env desync inside sheets).
    }
}
