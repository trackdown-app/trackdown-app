import Foundation

/// Names one game: a puzzle of a network.
public struct GameKey: Sendable, Hashable, Codable, CustomStringConvertible {
    public var network: Network
    public var number: Int

    public init(network: Network, number: Int) {
        self.network = network
        self.number = number
    }

    /// The key the website keeps this game under in `localStorage`, such as `trackdown:game:v1:nl:123`.
    public var storageKey: String { "trackdown:game:v1:\(network.rawValue):\(number)" }

    public var description: String { storageKey }
}

/// What is kept on the device for one game, after the website's `localStorage` value:
/// `{"guesses": [...], "archive": true, "outcome": "won"}`.
///
/// Only the guesses are kept, not their trips. Trips are rebuilt by replaying them through the guess endpoint,
/// since the server stores nothing. The website keeps each guess's `correct` instead; the app keeps `outcome`, so
/// the statistics can tell won from lost without replaying every past game.
public struct StoredGame: Sendable, Hashable, Codable {
    /// How a finished game ended. Spelled like the website's `GameStatus`.
    public enum Outcome: String, Sendable, Hashable, Codable {
        /// The last guess was the mystery station.
        case won
        /// Every guess was used and none was right.
        case lost
    }

    /// Every guess so far, in order.
    public var guesses: [StationCode]
    /// Whether the game was started from the archive rather than on its own day.
    public var archive: Bool
    /// How the game ended, or `nil` while it is still on.
    public var outcome: Outcome?
    /// The mystery station, once a finished game is revealed. The app keeps it so the archive can name past
    /// stations without asking the server again; the website does not store it.
    public var station: StationCode?

    public init(
        guesses: [StationCode],
        archive: Bool = false,
        outcome: Outcome? = nil,
        station: StationCode? = nil
    ) {
        self.guesses = guesses
        self.archive = archive
        self.outcome = outcome
        self.station = station
    }

    private enum CodingKeys: String, CodingKey {
        case guesses
        case archive
        case outcome
        case station
    }

    /// Reads `outcome` as `nil` when it is missing or a value this version does not know.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guesses = try container.decode([StationCode].self, forKey: .guesses)
        archive = try container.decodeIfPresent(Bool.self, forKey: .archive) ?? false
        outcome = (try? container.decodeIfPresent(String.self, forKey: .outcome)).flatMap(Outcome.init(rawValue:))
        station = try? container.decodeIfPresent(StationCode.self, forKey: .station)
    }

    /// Leaves `archive` out unless it is `true`, as the website does, and `outcome` and `station` out until they
    /// are known.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(guesses, forKey: .guesses)
        if archive {
            try container.encode(true, forKey: .archive)
        }
        try container.encodeIfPresent(outcome, forKey: .outcome)
        try container.encodeIfPresent(station, forKey: .station)
    }
}

/// Where games are kept between launches.
public protocol GameStorage: Sendable {
    /// The stored game for `key`, or `nil` when there is none or it cannot be read.
    func load(_ key: GameKey) -> StoredGame?

    /// Stores `game` under `key`, replacing what was there.
    func save(_ game: StoredGame, for key: GameKey) throws
}

/// Keeps every game as a JSON file in a folder, one file per game.
public struct FileGameStorage: GameStorage {
    /// Folder the files live in. Created on the first write.
    public var directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Storage in the app's Application Support folder, which survives relaunches and is backed up.
    public static var applicationSupport: FileGameStorage {
        FileGameStorage(
            directory: URL.applicationSupportDirectory.appending(path: "Games/v1", directoryHint: .isDirectory)
        )
    }

    public func load(_ key: GameKey) -> StoredGame? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        return try? JSONDecoder().decode(StoredGame.self, from: data)
    }

    public func save(_ game: StoredGame, for key: GameKey) throws {
        let data = try JSONEncoder().encode(game)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: key), options: .atomic)
    }

    private func fileURL(for key: GameKey) -> URL {
        directory.appending(path: "\(key.network.rawValue)-\(key.number).json", directoryHint: .notDirectory)
    }
}
