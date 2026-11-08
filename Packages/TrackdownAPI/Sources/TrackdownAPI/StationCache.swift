import Foundation
import GameCore

/// Keeps the station list on disk, one file per network and locale, so it is fetched at most once a day.
///
/// Best effort: a file that cannot be read or written is treated as missing.
public struct StationCache: Sendable {
    /// A cached station list and when it was fetched.
    public struct Entry: Sendable, Hashable, Codable {
        public var fetchedAt: Date
        public var stations: [Station]

        public init(fetchedAt: Date, stations: [Station]) {
            self.fetchedAt = fetchedAt
            self.stations = stations
        }
    }

    /// Folder the files live in. Created on the first write.
    public var directory: URL

    /// How long a fetched list stays fresh. The server asks clients to keep it for a day.
    public var maxAge: TimeInterval

    public init(directory: URL, maxAge: TimeInterval = 24 * 60 * 60) {
        self.directory = directory
        self.maxAge = maxAge
    }

    /// A cache in the app's Caches folder, which the system may purge when space runs low.
    public static var caches: StationCache {
        StationCache(directory: URL.cachesDirectory.appending(path: "Stations", directoryHint: .isDirectory))
    }

    public func entry(network: Network, locale: StationLocale) -> Entry? {
        guard let data = try? Data(contentsOf: fileURL(network: network, locale: locale)) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    public func store(_ entry: Entry, network: Network, locale: StationLocale) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(network: network, locale: locale), options: .atomic)
    }

    /// Whether `entry` was fetched less than ``maxAge`` before `now`. A fetch time in the future (the clock was
    /// changed) counts as stale.
    public func isFresh(_ entry: Entry, now: Date) -> Bool {
        let age = now.timeIntervalSince(entry.fetchedAt)
        return age >= 0 && age < maxAge
    }

    private func fileURL(network: Network, locale: StationLocale) -> URL {
        directory.appending(path: "\(network.rawValue)-\(locale.rawValue).json", directoryHint: .notDirectory)
    }
}
