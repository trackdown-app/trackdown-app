import SwiftUI
import Testing

@testable import DesignSystem

@Suite("Guess suggestions")
struct GuessSuggestionTests {
    static let rows = [
        GuessSuggestion(id: "asd", name: "Amsterdam Centraal"),
        GuessSuggestion(id: "asdz", name: "Amsterdam Zuid", isDisabled: true),
        GuessSuggestion(id: "ass", name: "Amsterdam Sloterdijk"),
        GuessSuggestion(id: "asb", name: "Amsterdam Bijlmer ArenA"),
    ]

    @Test("Bolds only the matched part of the name")
    func boldsMatch() {
        let name = "Amsterdam Centraal"
        let start = name.index(name.startIndex, offsetBy: 10)
        let range = start..<name.index(start, offsetBy: 3)
        let suggestion = GuessSuggestion(id: "asd", name: name, matchedRange: range)
        let runs = suggestion.attributedName.runs.map {
            (String(suggestion.attributedName[$0.range].characters), $0.font)
        }
        #expect(runs.map(\.0) == ["Amsterdam ", "Cen", "traal"])
        #expect(runs.map(\.1) == [TrackdownFont.body, TrackdownFont.headline, TrackdownFont.body])
    }

    @Test("Uses the body font throughout without a match")
    func noMatch() {
        let suggestion = GuessSuggestion(id: "asd", name: "Amsterdam Centraal")
        #expect(suggestion.attributedName.runs.count == 1)
        #expect(suggestion.attributedName.runs.first?.font == TrackdownFont.body)
    }

    @Test(
        "Arrow keys move the selection over enabled rows",
        arguments: [
            (nil, 1, "asd"),
            (nil, -1, "asb"),
            ("asd", 1, "ass"),
            ("ass", -1, "asd"),
            ("asb", 1, "asb"),
            ("asd", -1, "asd"),
            ("gone", 1, "asd"),
        ] as [(String?, Int, String?)]
    )
    func movesSelection(from: String?, offset: Int, expected: String?) {
        #expect(Self.rows.selection(movingFrom: from, by: offset) == expected)
    }

    @Test("Keeps no selection when every row is disabled")
    func allDisabled() {
        let rows = [GuessSuggestion(id: "asd", name: "Amsterdam Centraal", isDisabled: true)]
        #expect(rows.selection(movingFrom: nil, by: 1) == nil)
    }
}
