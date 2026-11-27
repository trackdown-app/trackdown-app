import Foundation
import Testing

@testable import GameCore

@Suite("Puzzle links")
struct PuzzleLinkTests {
    static let networkPaths = [
        "nl", "gb", "lu", "ret", "be", "en/nl", "en/gb", "en/lu", "en/ret", "en/be", "de/nl", "de/gb", "de/lu",
        "de/ret", "de/be", "fr/nl", "fr/gb", "fr/lu", "fr/ret", "fr/be",
    ]

    @Test("Opens today's puzzle in every language", arguments: networkPaths)
    func today(path: String) throws {
        let url = try #require(URL(string: "https://trackdown.nl/\(path)/?shared=1#result"))
        let network = try #require(Self.network(in: path))
        #expect(PuzzleLink(url: url) == .today(network))
    }

    @Test("Opens numbered archive puzzles", arguments: networkPaths)
    func archive(path: String) throws {
        let url = try #require(URL(string: "https://trackdown.nl/\(path)/archief/142"))
        let network = try #require(Self.network(in: path))
        #expect(PuzzleLink(url: url) == .archive(network, number: 142))
    }

    /// The network a test path names: its last part, after any language prefix.
    static func network(in path: String) -> Network? {
        path.split(separator: "/").last.flatMap { Network(rawValue: String($0)) }
    }

    @Test("No network's id is a language prefix, so a prefix is never read as a network")
    func prefixesAreNotNetworks() {
        for network in Network.allCases {
            #expect(!PuzzleLink.languagePrefixes.contains(Substring(network.rawValue)))
        }
    }

    @Test(
        "Unknown paths preserve the current network",
        arguments: [
            "", "en", "de", "fr", "ch", "nl/unknown", "en/gb/archief", "de/fr/nl", "en/de/nl", "es/nl",
            "nl/archief/0", "nl/archief/-1", "nl/archief/+1", "nl/archief/no",
            "nl/archief/999999999999999999999999", "nl/archief/1/extra", "nl//archief/1",
        ])
    func fallback(path: String) throws {
        let url = try #require(URL(string: "https://trackdown.nl/\(path)"))
        #expect(PuzzleLink(url: url) == .today(nil))
    }

    @Test(
        "Ignores unrelated origins",
        arguments: [
            "https://example.com/nl", "https://trackdown.nl.example.com/nl", "http://trackdown.nl/nl",
            "trackdown://nl", "https://trackdown.nl:8443/nl", "/nl",
        ])
    func unrelated(value: String) throws {
        let url = try #require(URL(string: value))
        #expect(PuzzleLink(url: url) == nil)
    }
}
