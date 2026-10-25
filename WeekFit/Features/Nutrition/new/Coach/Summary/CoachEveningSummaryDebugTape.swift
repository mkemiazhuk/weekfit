import Foundation

#if DEBUG
/// DEBUG-only evening-summary IO tape: console chunks + optional local export (no secrets).
@MainActor
enum CoachEveningSummaryDebugTape {
    struct Snapshot: Codable {
        var clientRequestId: String
        var serverRequestId: String?
        var generatedAt: String?
        var locale: String?
        var day: String?
        var appVersion: String
        var build: String
        var httpStatus: Int?
        var durationMs: Int?
        var uiSource: String?
        var displayedNote: String?
        var inputJSON: String
        var outputJSON: String?
        var transportError: String?
    }

    private(set) static var last: Snapshot?

    private static let chunkSize = 2_400

    static func logInput(clientRequestId: String, httpBody: Data) {
        let pretty = prettyJSON(httpBody) ?? String(data: httpBody, encoding: .utf8) ?? "<non-utf8 body>"
        printChunked(
            begin: "[CoachSummary][INPUT BEGIN] clientRequestId=\(clientRequestId)",
            end: "[CoachSummary][INPUT END] clientRequestId=\(clientRequestId)",
            body: pretty,
            requestId: clientRequestId
        )
        last = Snapshot(
            clientRequestId: clientRequestId,
            serverRequestId: nil,
            generatedAt: nil,
            locale: nil,
            day: nil,
            appVersion: appVersion,
            build: buildNumber,
            httpStatus: nil,
            durationMs: nil,
            uiSource: nil,
            displayedNote: nil,
            inputJSON: pretty,
            outputJSON: nil,
            transportError: nil
        )
    }

    static func logOutput(
        clientRequestId: String,
        serverRequestId: String?,
        status: Int?,
        durationMs: Int,
        responseBody: Data?,
        transportError: String? = nil
    ) {
        let pretty: String
        if let responseBody {
            pretty = prettyJSON(responseBody) ?? String(data: responseBody, encoding: .utf8) ?? "<non-utf8 body>"
        } else {
            pretty = "<no HTTP response body> transportError=\(transportError ?? "unknown")"
        }
        let server = serverRequestId ?? "-"
        let statusText = status.map(String.init) ?? "transport_error"
        printChunked(
            begin: "[CoachSummary][OUTPUT BEGIN] clientRequestId=\(clientRequestId) serverRequestId=\(server) status=\(statusText) durationMs=\(durationMs)",
            end: "[CoachSummary][OUTPUT END] clientRequestId=\(clientRequestId)",
            body: pretty,
            requestId: clientRequestId
        )
        if var bundle = last, bundle.clientRequestId == clientRequestId {
            bundle.serverRequestId = serverRequestId
            bundle.httpStatus = status
            bundle.durationMs = durationMs
            bundle.outputJSON = responseBody == nil ? nil : pretty
            bundle.transportError = transportError
            if let object = responseBody.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) {
                bundle.generatedAt = object["generatedAt"] as? String
                bundle.locale = object["locale"] as? String
                bundle.day = object["day"] as? String
            }
            last = bundle
        }
    }

    static func logUI(source: String, requestId: String?, generatedAt: String?, displayedNote: String) {
        let rid = requestId ?? "-"
        let generated = generatedAt ?? "-"
        print("[CoachSummary][UI] source=\(source) requestId=\(rid) generatedAt=\(generated)")
        printChunked(
            begin: "[CoachSummary][UI NOTE BEGIN] requestId=\(rid)",
            end: "[CoachSummary][UI NOTE END] requestId=\(rid)",
            body: displayedNote,
            requestId: rid
        )
        if var bundle = last {
            bundle.uiSource = source
            bundle.serverRequestId = requestId ?? bundle.serverRequestId
            bundle.generatedAt = generatedAt ?? bundle.generatedAt
            bundle.displayedNote = displayedNote
            last = bundle
        }
    }

    /// Explicit developer action — writes last IO bundle under Application Support (DEBUG only).
    @discardableResult
    static func exportLastToApplicationSupport() throws -> URL {
        guard let last else {
            throw CocoaError(.fileNoSuchFile)
        }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoachEveningSummaryDebug", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("last-\(last.clientRequestId).json")
        let data = try JSONEncoder().encode(last)
        let pretty = (try? JSONSerialization.jsonObject(with: data)).flatMap {
            try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted, .sortedKeys])
        } ?? data
        try pretty.write(to: url, options: .atomic)
        print("[CoachSummary][EXPORT] path=\(url.path)")
        return url
    }

    private static var appVersion: String {
        Foundation.Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private static var buildNumber: String {
        Foundation.Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    private static func prettyJSON(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: pretty, encoding: .utf8)
        else { return nil }
        return text
    }

    private static func printChunked(
        begin: String,
        end: String,
        body: String,
        requestId: String
    ) {
        print(begin)
        var start = body.startIndex
        var part = 1

        while start < body.endIndex {
            let next = body.index(
                start,
                offsetBy: chunkSize,
                limitedBy: body.endIndex
            ) ?? body.endIndex

            print("[CoachSummary][PART \(part) requestId=\(requestId)]\n\(body[start..<next])")
            start = next
            part += 1
        }

        print(end)
    }

    /// Test helper: split without printing; concatenating parts must equal `body`.
    static func chunkPartsForTesting(_ body: String, chunkSize: Int = chunkSize) -> [String] {
        var parts: [String] = []
        var start = body.startIndex
        while start < body.endIndex {
            let next = body.index(
                start,
                offsetBy: chunkSize,
                limitedBy: body.endIndex
            ) ?? body.endIndex
            parts.append(String(body[start..<next]))
            start = next
        }
        return parts
    }
}
#endif
