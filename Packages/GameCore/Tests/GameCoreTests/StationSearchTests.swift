import GameCore
import Testing

struct StationSearchTests {
    static let stations: [Station] = [
        Station(code: "asa", name: "Amsterdam Amstel", province: "Noord-Holland"),
        Station(code: "asd", name: "Amsterdam Centraal", province: "Noord-Holland"),
        Station(code: "amf", name: "Amersfoort Centraal", province: "Utrecht"),
        Station(code: "dvd", name: "Duivendrecht", province: "Noord-Holland"),
        Station(code: "ht", name: "'s-Hertogenbosch", province: "Noord-Brabant"),
        Station(code: "bnc", name: "Brussel-Centraal", province: "Brussel"),
        Station(code: "ldd", name: "Leeuwarden", province: "Friesland"),
        Station(code: "zl", name: "Zwolle", province: "Overijssel"),
        Station(code: "cre", name: "Créteil", province: "Île-de-France"),
    ]

    let search = StationSearch(stations: Self.stations)

    @Test("Puts prefix matches first, then word-prefix, then contains")
    func ranking() {
        let matches = search.matches(for: "am")

        #expect(matches.map(\.station.code) == ["asa", "asd", "amf"])
        #expect(matches.map(\.kind) == [.prefix, .prefix, .prefix])

        let centraal = search.matches(for: "cen")
        #expect(centraal.map(\.station.code) == ["asd", "amf", "bnc"])
        #expect(centraal.map(\.kind) == [.wordPrefix, .wordPrefix, .wordPrefix])

        let drecht = search.matches(for: "dre")
        #expect(drecht.map(\.station.code) == ["dvd"])
        #expect(drecht.map(\.kind) == [.contains])
    }

    @Test("Ranks a word-prefix match above an earlier contains match in another name")
    func wordPrefixBeatsContains() {
        let matches = search.matches(for: "ams")

        // "Amsterdam Amstel" is a prefix match; its later "Amstel" does not demote it.
        #expect(matches.map(\.station.code) == ["asa", "asd"])
        #expect(matches.allSatisfy { $0.kind == .prefix })

        let stel = StationSearch(stations: [
            Station(code: "a", name: "Kastel", province: ""),
            Station(code: "b", name: "Oud Stel", province: ""),
        ])
        #expect(stel.matches(for: "stel").map(\.station.code) == ["b", "a"])
    }

    @Test("Treats punctuation as a word boundary", arguments: ["hert", "Hertogenbosch"])
    func punctuationBoundary(query: String) throws {
        let match = try #require(search.matches(for: query).first)

        #expect(match.station.code == "ht")
        #expect(match.kind == .wordPrefix)
    }

    @Test("Ignores case, diacritics and surrounding whitespace", arguments: ["CRET", "cret", "crét", "  Cré  "])
    func folding(query: String) throws {
        let match = try #require(search.matches(for: query).first)

        #expect(match.station.code == "cre")
        #expect(match.kind == .prefix)
    }

    @Test("Returns the matched range in the original name")
    func matchedRange() throws {
        let ams = try #require(search.matches(for: "ams").first)
        #expect(ams.matchedText == "Ams")
        #expect(ams.station.name[ams.matchedRange.upperBound...] == "terdam Amstel")

        let centraal = try #require(search.matches(for: "CENTRAAL").first)
        #expect(centraal.matchedText == "Centraal")

        let creteil = try #require(search.matches(for: "creteil").first)
        #expect(creteil.matchedText == "Créteil")

        let inside = try #require(search.matches(for: "ete").first)
        #expect(inside.kind == .contains)
        #expect(inside.matchedText == "éte")
    }

    @Test("Exposes the province for the subtitle")
    func province() throws {
        let match = try #require(search.matches(for: "zwol").first)

        #expect(match.station.province == "Overijssel")
    }

    @Test("Marks stations that were already guessed")
    func guessed() {
        let matches = search.matches(for: "am", guessed: ["asd"])

        #expect(matches.map(\.station.code) == ["asa", "asd", "amf"])
        #expect(matches.map(\.isGuessed) == [false, true, false])
    }

    @Test("Matches nothing for an empty query", arguments: ["", " ", "\n"])
    func empty(query: String) {
        #expect(search.matches(for: query).isEmpty)
    }

    @Test("Matches nothing when no name contains the query")
    func noMatch() {
        #expect(search.matches(for: "xyz").isEmpty)
        #expect(search.matches(for: "amsterdam centraal station").isEmpty)
    }

    @Test("Returns at most limit matches, best first")
    func limit() {
        #expect(search.matches(for: "a", limit: 2).map(\.station.code) == ["asa", "asd"])
        #expect(search.matches(for: "a", limit: 0).isEmpty)
    }

    @Test(
        "Searches a full NL station list in under 5 ms",
        arguments: ["a", "ams", "cen", "zuid", "é", "xyz", "'s-h", "Amsterdam Centraal 1"])
    func performance(query: String) {
        let search = StationSearch(stations: Self.syntheticNetwork(count: 450))
        let clock = ContinuousClock()

        // The fastest of several runs, so one hiccup on a busy CI machine does not fail the test.
        let fastest = (0..<5).map { _ in clock.measure { _ = search.matches(for: query) } }.min() ?? .zero

        #expect(fastest < .milliseconds(5), "\(query) took \(fastest)")
    }

    /// About as many stations as the NL network, with realistic names, lengths and diacritics.
    static func syntheticNetwork(count: Int) -> [Station] {
        let places = [
            "Amsterdam", "Rotterdam", "'s-Hertogenbosch", "Den Haag", "Utrecht", "Eindhoven", "Groningen",
            "Zoetermeer", "Hoogezand-Sappemeer", "Nijmegen", "Bruxelles", "Liège", "Köln", "Düsseldorf",
        ]
        let suffixes = [
            "Centraal", "Zuid", "Noord", "Oost", "West", "Bijlmer ArenA", "Lombardijen", "Mariënberg", "Heuvel",
        ]
        return (0..<count).map { index in
            let place = places[index % places.count]
            let suffix = suffixes[(index / places.count) % suffixes.count]
            return Station(
                code: StationCode("s\(index)"),
                name: "\(place) \(suffix) \(index)",
                province: "Provincie \(index % 12)"
            )
        }
    }
}
