import SwiftUI

struct WeekFitScreenContainer<Header: View, Content: View>: View {

    let header: Header
    let content: Content

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                .padding(.top, WeekFitScreenLayout.topPadding)
                .padding(.bottom, WeekFitScreenLayout.headerBottomSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)

            content
                .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
