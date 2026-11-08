import Foundation

/// Searches a network's station list locally, so the guess field can autocomplete on every keystroke without a
/// network call.
///
/// Build one per station list (for example the cached list of the current network) and reuse it: the initializer
/// prepares every name once, so ``matches(for:guessed:limit:)`` only compares bytes.
///
/// Matching ignores case and diacritics, so `"bruxelles"` finds `Bruxelles` and `"hert"` finds `'s-Hertogenbosch`.
/// Punctuation and spaces must match as typed. See ``StationMatch/Kind`` for the order results come in.
public struct StationSearch: Sendable {
    /// One station with its name prepared for matching.
    private struct Entry: Sendable {
        var station: Station
        /// The folded name as UTF-8 bytes.
        var folded: [UInt8]
        /// For every byte of `folded`, the offset of the character in `station.name` it came from.
        var origin: [Int]
        /// Where each character of `station.name` starts, plus `endIndex`, indexed by character offset.
        var characterIndices: [String.Index]
        /// Whether a word starts at each byte of `folded`.
        var wordStart: [Bool]
    }

    private let entries: [Entry]

    /// - Parameter stations: The stations to search, in the order equally good matches should come back in
    ///   (``PuzzleService/stations(network:locale:)`` returns them sorted by name).
    public init(stations: [Station]) {
        entries = stations.map(Self.entry(for:))
    }

    /// The stations whose name contains `query`, best first.
    ///
    /// Results come in three groups: names that start with `query`, then names with a word that starts with it,
    /// then names that contain it anywhere. Within a group they keep the order of the station list. Case,
    /// diacritics and leading or trailing whitespace in `query` are ignored.
    ///
    /// - Parameters:
    ///   - query: What the player has typed. An empty or all-whitespace query matches nothing.
    ///   - guessed: Stations already guessed in this game. They still match, with ``StationMatch/isGuessed`` set,
    ///     so the UI can show them as unavailable.
    ///   - limit: The most matches to return.
    public func matches(for query: String, guessed: Set<StationCode> = [], limit: Int = .max) -> [StationMatch] {
        let needle = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines)).bytes
        guard !needle.isEmpty, limit > 0 else { return [] }

        var groups: [[StationMatch]] = [[], [], []]
        for entry in entries {
            guard let (kind, start) = Self.bestMatch(of: needle, in: entry) else { continue }
            let end = start + needle.count
            let lower = entry.characterIndices[entry.origin[start]]
            let upper = entry.characterIndices[entry.origin[end - 1] + 1]
            groups[kind.rawValue].append(
                StationMatch(
                    station: entry.station,
                    kind: kind,
                    matchedRange: lower..<upper,
                    isGuessed: guessed.contains(entry.station.code)
                ))
            // The first group alone fills the limit, so later stations cannot make the cut.
            if groups[0].count >= limit { break }
        }
        return Array(groups.joined().prefix(limit))
    }

    /// The best kind of match of `needle` in `entry`, and the byte offset it starts at.
    private static func bestMatch(of needle: [UInt8], in entry: Entry) -> (StationMatch.Kind, Int)? {
        let haystack = entry.folded
        guard needle.count <= haystack.count else { return nil }

        var firstContains: Int?
        for start in 0...(haystack.count - needle.count) where haystack[start] == needle[0] {
            guard bytes(haystack, at: start, startWith: needle) else { continue }
            if start == 0 { return (.prefix, 0) }
            if entry.wordStart[start] { return (.wordPrefix, start) }
            if firstContains == nil { firstContains = start }
        }
        return firstContains.map { (.contains, $0) }
    }

    private static func bytes(_ haystack: [UInt8], at start: Int, startWith needle: [UInt8]) -> Bool {
        for offset in 1..<needle.count where haystack[start + offset] != needle[offset] {
            return false
        }
        return true
    }

    private static func entry(for station: Station) -> Entry {
        let name = station.name
        let folded = fold(name)
        var characterIndices = Array(name.indices)
        characterIndices.append(name.endIndex)

        var wordStart = [Bool](repeating: false, count: folded.bytes.count)
        var previousIsWordCharacter = false
        var characterOffset = -1
        for (byte, origin) in zip(wordStart.indices, folded.origin) where origin != characterOffset {
            characterOffset = origin
            let character = name[characterIndices[origin]]
            wordStart[byte] = !previousIsWordCharacter
            previousIsWordCharacter = character.isLetter || character.isNumber
        }

        return Entry(
            station: station,
            folded: folded.bytes,
            origin: folded.origin,
            characterIndices: characterIndices,
            wordStart: wordStart
        )
    }

    /// `string` without case or diacritics, as UTF-8 bytes, with the offset of the character each byte came from.
    ///
    /// Folds one character at a time so every byte maps back to exactly one character of `string`.
    private static func fold(_ string: String) -> (bytes: [UInt8], origin: [Int]) {
        var bytes: [UInt8] = []
        var origin: [Int] = []
        bytes.reserveCapacity(string.utf8.count)
        origin.reserveCapacity(string.utf8.count)
        for (offset, character) in string.enumerated() {
            let folded = String(character)
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                .lowercased()
            bytes.append(contentsOf: folded.utf8)
            origin.append(contentsOf: repeatElement(offset, count: folded.utf8.count))
        }
        return (bytes, origin)
    }
}

/// A station that matches a ``StationSearch`` query.
public struct StationMatch: Sendable, Hashable, Identifiable {
    /// How a name matched, best first.
    public enum Kind: Int, Sendable, Hashable, Comparable {
        /// The name starts with the query: `Ams` in `Amsterdam Centraal`.
        case prefix
        /// A later word of the name starts with the query: `Cen` in `Amsterdam Centraal`, `Hert` in
        /// `'s-Hertogenbosch`.
        case wordPrefix
        /// The query is somewhere inside a word: `dam` in `Amsterdam Centraal`.
        case contains

        public static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public var station: Station
    public var kind: Kind
    /// The part of `station.name` that matched, for the UI to bold. Covers whole characters of the name, so
    /// `ams` matches `Åms` with all three characters.
    public var matchedRange: Range<String.Index>
    /// Whether the player already guessed this station in this game.
    public var isGuessed: Bool

    public var id: StationCode { station.code }

    /// The matched part of the name, such as `Ams` for `Amsterdam Centraal`.
    public var matchedText: Substring { station.name[matchedRange] }

    public init(station: Station, kind: Kind, matchedRange: Range<String.Index>, isGuessed: Bool) {
        self.station = station
        self.kind = kind
        self.matchedRange = matchedRange
        self.isGuessed = isGuessed
    }
}
