import Foundation
import GameCore
import Testing

@testable import GameScreens

@Suite("Share text")
struct ShareTextTests {
    /// The design's game: four wrong guesses, then the mystery station.
    static let solved = Game(
        key: GameKey(network: .nl, number: 142),
        maxGuesses: 6,
        guesses: ["mt", "dh", "ut", "hvs", "amf"],
        trips: [
            GuessTrip(
                guess: "mt", correct: false,
                steps: [
                    .ride(train: "IC", minutes: 122), .change(station: nil, minutes: 6),
                    .ride(train: "IC", minutes: 17),
                ]),
            GuessTrip(
                guess: "dh", correct: false,
                steps: [
                    .ride(train: "IC", minutes: 72), .change(station: "asd", minutes: 9),
                    .ride(train: "IC", minutes: 36),
                ]),
            GuessTrip(guess: "ut", correct: false, steps: [.ride(train: "IC", minutes: 17)]),
            GuessTrip(guess: "hvs", correct: false, steps: [.ride(train: "SPR", minutes: 13)]),
            GuessTrip(guess: "amf", correct: true, steps: []),
        ]
    )

    static let lost = Game(
        key: GameKey(network: .nl, number: 142),
        maxGuesses: 2,
        guesses: ["ut", "hvs"],
        trips: [
            GuessTrip(guess: "ut", correct: false, steps: [.ride(train: "IC", minutes: 17)]),
            GuessTrip(guess: "hvs", correct: false, steps: [.ride(train: "SPR", minutes: 13)]),
        ]
    )

    @Test("Writes the design's text for a solved game")
    func solvedInEnglish() throws {
        let text = try #require(ShareText.text(for: Self.solved, language: .en))
        #expect(
            text == """
                Trackdown NL 142, 5/6
                ●━━━━━━━━○━  2h25
                ●━━━━━○━━    1h57
                ●━           17m
                ●━           13m
                Tracked down in 5
                https://trackdown.nl/en/nl
                """)
    }

    @Test("Scores a lost game X and says it was not tracked down")
    func lostInEnglish() throws {
        let text = try #require(ShareText.text(for: Self.lost, language: .en))
        #expect(
            text == """
                Trackdown NL 142, X/2
                ●━  17m
                ●━  13m
                Not tracked down
                https://trackdown.nl/en/nl
                """)
    }

    @Test("Writes Dutch times, footer and link in Dutch")
    func dutch() throws {
        let text = try #require(ShareText.text(for: Self.solved, language: .nl))
        #expect(
            text == """
                Trackdown NL 142, 5/6
                ●━━━━━━━━○━  2u25
                ●━━━━━○━━    1u57
                ●━           17m
                ●━           13m
                Gevonden in 5
                https://trackdown.nl/nl
                """)
        let lost = try #require(ShareText.text(for: Self.lost, language: .nl))
        #expect(lost.hasSuffix("Niet gevonden\nhttps://trackdown.nl/nl"))
    }

    @Test(
        "Writes times as the grid does", arguments: [(0, "0m"), (17, "17m"), (60, "1h00"), (65, "1h05"), (145, "2h25")])
    func minutes(minutes: Int, expected: String) {
        #expect(ShareText.minutes(minutes, language: .en) == expected)
    }

    @Test("Draws one stretch of line per 15 minutes, at least one, and a ring per change")
    func line() {
        #expect(ShareText.line([.ride(train: "IC", minutes: 5)]) == "●━")
        #expect(ShareText.line([.ride(train: "IC", minutes: 22)]) == "●━")
        #expect(ShareText.line([.ride(train: "IC", minutes: 23)]) == "●━━")
        #expect(
            ShareText.line([
                .ride(train: "IC", minutes: 30), .change(station: "ut", minutes: 5), .ride(train: "IC", minutes: 15),
            ])
                == "●━━○━")
    }

    @Test("Never names a station")
    func noStationNames() throws {
        let text = try #require(ShareText.text(for: Self.solved, language: .en))
        for code in Self.solved.guesses + ["asd"] {
            #expect(!text.contains(code.rawValue))
        }
    }

    @Test("Has no text while the game is on")
    func playing() {
        let game = Game(key: GameKey(network: .nl, number: 142), maxGuesses: 6, guesses: [], trips: [])
        #expect(ShareText.text(for: game, language: .en) == nil)
    }
}
