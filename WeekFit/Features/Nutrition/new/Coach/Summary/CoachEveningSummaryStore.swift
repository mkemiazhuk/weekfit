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
        /// Fingerprint that produced this summary (`day:YYYY-MM-DD` in once-per-day mode).
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

    /// Test seam so repeated restores can be counted without a second disk implementation.
    var onLoadCache: (() -> Void)?

    func loadCache(owner: String) throws -> LastingCache? {
        onLoadCache?()
        let url = cacheFile(owner: owner)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(LastingCache.self, from: Data(contentsOf: url))
    }

    func saveCache(_ cache: LastingCache, owner: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(cache).write(to: cacheFile(owner: owner), options: .atomic)
        // Also persist into the day claim so prior recaps survive when latest.json is overwritten.
        if var claim = try? record(owner: owner, day: cache.summary.day) {
            claim.summary = cache.summary
            try? saveClaim(claim, owner: owner)
        } else {
            try? saveClaim(Record(day: cache.summary.day, summary: cache.summary), owner: owner)
        }
    }

    /// Compact prior evening notes for the same owner (excludes `beforeDay` and newer).
    func loadRecentRecaps(owner: String, beforeDay: String, limit: Int) throws -> [CoachEveningSummaryInput.Fact] {
        guard limit > 0, FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let prefix = "\(ownerHash(owner))-"
        var collected: [(day: String, summary: CoachEveningSummary)] = []
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let name = file.lastPathComponent
            guard name.hasPrefix(prefix), name.hasSuffix(".json"), !name.hasSuffix("-latest.json") else { continue }
            guard let record = try? JSONDecoder().decode(Record.self, from: Data(contentsOf: file)),
                  let summary = record.summary,
                  record.day < beforeDay else { continue }
            collected.append((record.day, summary))
        }
        if let cache = try? loadCache(owner: owner),
           cache.summary.day < beforeDay,
           !collected.contains(where: { $0.day == cache.summary.day }) {
            collected.append((cache.summary.day, cache.summary))
        }
        return collected
            .sorted { $0.day > $1.day }
            .prefix(limit)
            .enumerated()
            .map { index, item in
                let theme = item.summary.headline.trimmingCharacters(in: .whitespacesAndNewlines)
                let advice = item.summary.tomorrow.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let text = String(("Previous recap \(item.day); theme=\(theme); advice=\(advice)").prefix(240))
                return .init(id: "history.recap.\(index).\(item.day)", text: text)
            }
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
