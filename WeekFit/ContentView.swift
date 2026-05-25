import SwiftUI

struct ContentView: View {

    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isLoggedIn {
                TodayView(authViewModel: authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
    }
}
