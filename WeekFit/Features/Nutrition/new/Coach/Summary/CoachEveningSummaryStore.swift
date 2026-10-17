import Foundation
import CryptoKit

/// Lasting successful-summary cache (per owner) plus optional once-per-day attempt ledger.
/// Cache survives midnight and app relaunch. Daily claims never block manual refresh in test mode.
@MainActor
final class CoachEveningSummaryStore {
    struct Record: Codable {
        let day: String
        var summary: CoachEveningSummary?
    }

    struct LastingCache: Codable, Equatable {
        var summary: CoachEveningSummary
        var receivedAt: Date
        /// Activity/day fingerprint that produced this summary — regenerate when it changes.
        var inputFingerprint: String?

        init(summary: CoachEveningSummary, receivedAt: Date, inputFingerprint: String? = nil) {
            self.summary = summary
            self.receivedAt = receivedAt
            self.inputFingerprint = inputFingerprint
        }

        private enum CodingKeys: String, CodingKey {
            case summary, receivedAt, inputFingerprint
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            summary = try c.decode(CoachEveningSummary.self, forKey: .summary)
            receivedAt = try c.decode(Date.self, forKey: .receivedAt)
            inputFingerprint = try c.decodeIfPresent(String.self, forKey: .inputFingerprint)
        }
    }

    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoachEveningSummary", isDirectory: true)
    }

    private func ownerHash(_ owner: String) -> String {
        SHA256.hash(data: Data(owner.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func claimFile(owner: String, day: String) -> URL {
        directory.appendingPathComponent("\(ownerHash(owner))-\(day).json")
    }

    private func cacheFile(owner: String) -> URL {
        directory.appendingPathComponent("\(ownerHash(owner))-latest.json")
    }

    // MARK: Lasting cache (manual / display)

    func loadCache(owner: String) throws -> LastingCache? {
        let url = cacheFile(owner: owner)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(LastingCache.self, from: Data(contentsOf: url))
    }

    func saveCache(_ cache: LastingCache, owner: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(cache).write(to: cacheFile(owner: owner), options: .atomic)
    }

    // MARK: Once-per-day claim ledger (production flag)

    func record(owner: String, day: String) throws -> Record? {
        let url = claimFile(owner: owner, day: day)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
    }

    func claim(owner: String, day: String) throws -> Bool {
        guard try record(owner: owner, day: day) == nil else { return false }
        try saveClaim(Record(day: day, summary: nil), owner: owner)
        return true
    }

    func saveClaim(_ record: Record, owner: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: claimFile(owner: owner, day: record.day), options: .atomic)
    }

    /// Clears lasting caches and summary text inside claim files; keeps claim markers so production
    /// once-per-day mode cannot be reset by wiping local text alone.
    func eraseSummaryTextPreservingAttempts() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            guard file.pathExtension == "json" else { continue }
            if file.lastPathComponent.hasSuffix("-latest.json") {
                try FileManager.default.removeItem(at: file)
                continue
            }
            var record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: file))
            record.summary = nil
            try JSONEncoder().encode(record).write(to: file, options: .atomic)
        }
    }
}

extension Notification.Name {
    static let coachEveningSummaryWillReset = Notification.Name("coachEveningSummaryWillReset")
}
