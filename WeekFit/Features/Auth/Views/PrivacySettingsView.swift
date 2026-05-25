import SwiftUI

struct PrivacySettingsView: View {

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Text("Privacy Settings")
                .font(.title.bold())
                .foregroundStyle(.white)
        }
    }
}

