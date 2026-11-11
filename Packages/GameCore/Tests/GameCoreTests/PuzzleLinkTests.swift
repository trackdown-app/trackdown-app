import Foundation
import Testing

@testable import GameCore

@Suite("Puzzle links")
struct PuzzleLinkTests {
    @Test("Opens today's puzzle in either language", arguments: ["nl", "gb", "en/nl", "en/gb"])
    func today(path: String) throws {
        let url = try #require(URL(string: "https://trackdown.nl/\(path)/?shared=1#result"))
        let network = try #require(Network(rawValue: String(path.suffix(2))))
        #expect(PuzzleLink(url: url) == .today(network))
    }

    @Test("Opens numbered archive puzzles", arguments: ["nl", "gb", "en/nl", "en/gb"])
    func archive(path: String) throws {
        let url = try #require(URL(string: "https://trackdown.nl/\(path)/archief/142"))
        let network = try #require(Network(rawValue: String(path.suffix(2))))
        #expect(PuzzleLink(url: url) == .archive(network, number: 142))
    }

    @Test(
        "Unknown paths preserve the current network",
        arguments: [
            "", "en", "be", "nl/unknown", "en/gb/archief", "nl/archief/0", "nl/archief/-1",
            "nl/archief/+1", "nl/archief/no", "nl/archief/999999999999999999999999",
            "nl/archief/1/extra", "nl//archief/1",
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
