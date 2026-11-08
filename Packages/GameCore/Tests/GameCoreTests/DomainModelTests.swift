import Foundation
import GameCore
import Testing

struct PuzzleDateTests {
    @Test("Parses a YYYY-MM-DD day")
    func parses() throws {
        let date = try #require(PuzzleDate(iso8601: "2026-03-07"))

        #expect(date == PuzzleDate(year: 2026, month: 3, day: 7))
        #expect(date.iso8601 == "2026-03-07")
    }

    @Test(
        "Rejects anything that is not a real YYYY-MM-DD day",
        arguments: [
            "", "2026-3-7", "2026-02-30", "2026-13-01", "26-03-07", "2026-03-07T00:00:00Z", "2026/03/07",
        ])
    func rejects(string: String) {
        #expect(PuzzleDate(iso8601: string) == nil)
    }

    @Test("Orders days by year, then month, then day")
    func orders() {
        #expect(PuzzleDate(year: 2025, month: 12, day: 31) < PuzzleDate(year: 2026, month: 1, day: 1))
        #expect(PuzzleDate(year: 2026, month: 1, day: 31) < PuzzleDate(year: 2026, month: 2, day: 1))
        #expect(PuzzleDate(year: 2026, month: 2, day: 1) < PuzzleDate(year: 2026, month: 2, day: 2))
    }

    @Test("Round-trips through JSON as a YYYY-MM-DD string")
    func codable() throws {
        let date = PuzzleDate(year: 2026, month: 11, day: 8)
        let data = try JSONEncoder().encode([date])

        #expect(String(decoding: data, as: UTF8.self) == #"["2026-11-08"]"#)
        #expect(try JSONDecoder().decode([PuzzleDate].self, from: data) == [date])
    }
}

struct StationLocaleTests {
    @Test("Dutch for any Dutch first language", arguments: ["nl", "nl-NL", "nl-BE", "nl_NL"])
    func dutch(language: String) {
        #expect(StationLocale.preferred(languages: [language, "en"]) == .nl)
    }

    @Test(
        "English for any other first language, even when Dutch comes later",
        arguments: [
            ["en-GB"], ["de-DE", "nl-NL"], ["fy-NL"], [],
        ])
    func english(languages: [String]) {
        #expect(StationLocale.preferred(languages: languages) == .en)
    }
}

struct TripStepTests {
    @Test("Exposes the minutes of both kinds of step")
    func minutes() {
        #expect(TripStep.ride(train: "IC", minutes: 12).minutes == 12)
        #expect(TripStep.change(station: nil, minutes: 4).minutes == 4)
    }
}
