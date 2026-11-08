import Foundation

/// A rail network the game has puzzles for.
public enum Network: String, Sendable, Hashable, Codable, CaseIterable {
    case nl
    case gb
}

/// A station's code, such as `asd` for Amsterdam Centraal. Stable across locales.
public struct StationCode: RawRepresentable, Sendable, Hashable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

/// A calendar day as the server names it (`YYYY-MM-DD`), free of any time zone.
public struct PuzzleDate: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `YYYY-MM-DD`. Returns `nil` for anything else, including impossible days such as `2026-02-30`.
    public init?(iso8601 string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar) else { return nil }

        self.init(year: year, month: month, day: day)
    }

    /// The day as `YYYY-MM-DD`.
    public var iso8601: String {
        let month = month < 10 ? "0\(month)" : "\(month)"
        let day = day < 10 ? "0\(day)" : "\(day)"
        return "\(year)-\(month)-\(day)"
    }

    public var description: String { iso8601 }

    public static func < (lhs: PuzzleDate, rhs: PuzzleDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = PuzzleDate(iso8601: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a YYYY-MM-DD date: \(string)")
        }
        self = date
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso8601)
    }
}

/// Today's puzzle, without its answer.
public struct Puzzle: Sendable, Hashable {
    public var network: Network
    public var number: Int
    public var date: PuzzleDate
    public var maxGuesses: Int
    /// When the next puzzle comes out, and so when this one stops being today's.
    public var nextPuzzleAt: Date

    public init(network: Network, number: Int, date: PuzzleDate, maxGuesses: Int, nextPuzzleAt: Date) {
        self.network = network
        self.number = number
        self.date = date
        self.maxGuesses = maxGuesses
        self.nextPuzzleAt = nextPuzzleAt
    }
}

/// A puzzle in the archive: every puzzle up to today's.
public struct ArchivedPuzzle: Sendable, Hashable {
    public var number: Int
    public var date: PuzzleDate

    public init(number: Int, date: PuzzleDate) {
        self.number = number
        self.date = date
    }
}
