import Foundation
import FirebaseAuth

enum CoachEveningSummaryServiceError: Error {
    case unavailable
    case invalidResponse
    case server(Int)
}

@MainActor
enum CoachEveningSummaryService {
    static func generate(_ input: CoachEveningSummaryInput, owner: String) async throws -> CoachEveningSummary {
        try Task.checkCancellation()
        guard FirebaseBootstrap.isConfigured else { throw CoachEveningSummaryServiceError.unavailable }
        guard WorkspaceOwnerStore.currentIdentityToken() == owner else { throw CancellationError() }
        let auth = Auth.auth()
        let ownerKey = "weekfit.ai.firebaseWorkspaceOwner"
        if UserDefaults.standard.string(forKey: ownerKey) != owner {
            // The current app uses local/Apple workspace identities independently of Firebase.
            // Never let another workspace reuse an anonymous UID and read its saved summary.
            guard auth.currentUser == nil || auth.currentUser?.isAnonymous == true else {
                throw CoachEveningSummaryServiceError.unavailable
            }
            try auth.signOut()
        }
        if auth.currentUser == nil { _ = try await auth.signInAnonymously() }
        try Task.checkCancellation()
        guard WorkspaceOwnerStore.currentIdentityToken() == owner else { throw CancellationError() }
        UserDefaults.standard.set(owner, forKey: ownerKey)
        guard let user = auth.currentUser else { throw CoachEveningSummaryServiceError.unavailable }
        let token = try await user.getIDToken()
        try Task.checkCancellation()
        guard let url = URL(string: "https://weekfit-food-photo.onrender.com/v1/coach/day-summary") else {
            throw CoachEveningSummaryServiceError.unavailable
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(input)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CoachEveningSummaryServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw CoachEveningSummaryServiceError.server(http.statusCode) }
        let summary = try JSONDecoder().decode(CoachEveningSummary.self, from: data)
        guard summary.isValid(for: input) else { throw CoachEveningSummaryServiceError.invalidResponse }
        return summary
    }
}
