import SwiftUI

extension View {
    func weekFitSheetChrome(cornerRadius: CGFloat? = nil) -> some View {
        self
            .presentationBackground(.clear)
            .presentationCornerRadius(cornerRadius)
            .preferredColorScheme(.dark)
            .environment(\.weekFitPalette, WeekFitPaletteStore.current)
    }
}
