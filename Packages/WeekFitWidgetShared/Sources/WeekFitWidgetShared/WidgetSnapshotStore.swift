import Foundation

/// Reads/writes `WeekFitWidgetSnapshot` in the shared App Group container.
public enum WidgetSnapshotStore {
    public static let fileName = "weekfit-widget-snapshot.json"

    public static func containerURL(
        fileManager: FileManager = .default,
        appGroupID: String = WeekFitAppGroup.identifier
    ) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    public static func snapshotURL(
        fileManager: FileManager = .default,
        appGroupID: String = WeekFitAppGroup.identifier
    ) -> URL? {
        containerURL(fileManager: fileManager, appGroupID: appGroupID)?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    @discardableResult
    public static func save(
        _ snapshot: WeekFitWidgetSnapshot,
        fileManager: FileManager = .default,
        appGroupID: String = WeekFitAppGroup.identifier
    ) throws -> URL {
        guard let url = snapshotURL(fileManager: fileManager, appGroupID: appGroupID) else {
            throw StoreError.appGroupUnavailable
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
        return url
    }

    public static func load(
        fileManager: FileManager = .default,
        appGroupID: String = WeekFitAppGroup.identifier
    ) throws -> WeekFitWidgetSnapshot? {
        guard let url = snapshotURL(fileManager: fileManager, appGroupID: appGroupID) else {
            throw StoreError.appGroupUnavailable
        }
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WeekFitWidgetSnapshot.self, from: data)
    }

    public enum StoreError: Error, Equatable {
        case appGroupUnavailable
    }
}
