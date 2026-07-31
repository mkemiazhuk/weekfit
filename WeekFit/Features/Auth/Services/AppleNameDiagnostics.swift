import Foundation
import AuthenticationServices

/// DEBUG-only Apple Sign In request/error probes. Verbose credential dumps were removed
/// after confirming Apple can return empty `PersonNameComponents`.
enum AppleNameDiagnostics {

    #if DEBUG
    static func logRequestedScopes(_ scopes: [ASAuthorization.Scope]) {
        let labels = scopes.map(\.rawValue).joined(separator: ",")
        print("[AppleNameDiag] checkpoint=0_request requestedScopes=[\(labels)]")
    }

    static func logError(_ message: String, checkpoint: String = "error") {
        print("[AppleNameDiag] checkpoint=\(checkpoint) \(message)")
    }
    #else
    static func logRequestedScopes(_ scopes: [ASAuthorization.Scope]) {}
    static func logError(_ message: String, checkpoint: String = "error") {}
    #endif
}
