import SwiftUI

struct ContentView: View {

    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isLoggedIn {
                WeekFitRootView(authViewModel: authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .onAppear {
            #if DEBUG
            authViewModel.applyUITestBypassIfNeeded()
            #endif
        }
    }
}
