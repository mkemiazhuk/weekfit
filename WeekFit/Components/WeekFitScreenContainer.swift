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
        GeometryReader { proxy in

            let width = proxy.size.width

            VStack(spacing: 0) {

                header
                    .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                    .padding(.top, WeekFitScreenLayout.topPadding)
                    .padding(.bottom, 12)
                    .frame(width: width)
//                    .debugFrame("Header shell")

                content
                    .frame(
                        width: width - (WeekFitScreenLayout.horizontalPadding * 2)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                    .clipped()
//                    .debugFrame("Content shell")
            }
            .frame(width: width, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
//            .debugFrame("Root shell")
        }
    }
}
