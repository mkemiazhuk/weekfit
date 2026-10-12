import Foundation
import CryptoKit

/// An attempt is written atomically BEFORE auth/network. Failure is terminal for this day.
/// The ledger is scoped to the local workspace, not locale, metrics or view lifetime.
@MainActor
final class CoachEveningSummaryStore {
    struct Record: Codable {
        let day: String
        var summary: CoachEveningSummary?
    }

    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoachEveningSummary", isDirectory: true)
    }

    private func file(owner: String, day: String) -> URL {
        let hash = SHA256.hash(data: Data(owner.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(hash)-\(day).json")
    }

    func record(owner: String, day: String) throws -> Record? {
        let url = file(owner: owner, day: day)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        // Corrupt records fail closed: never spend a second request to repair a ledger.
        return try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
    }

    func claim(owner: String, day: String) throws -> Bool {
        guard try record(owner: owner, day: day) == nil else { return false }
        try save(Record(day: day, summary: nil), owner: owner)
        return true
    }

    func save(_ record: Record, owner: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: file(owner: owner, day: record.day), options: .atomic)
    }

    func eraseSummaryTextPreservingAttempts() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            guard file.pathExtension == "json" else { continue }
            var record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: file))
            record.summary = nil
            try JSONEncoder().encode(record).write(to: file, options: .atomic)
        }
    }
}

extension Notification.Name {
    static let coachEveningSummaryWillReset = Notification.Name("coachEveningSummaryWillReset")
}
