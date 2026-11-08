import Foundation
import GameCore
import Testing

struct PuzzleCalendarTests {
    @Test(
        "Names the Amsterdam day, not the UTC one",
        arguments: [
            ("2026-03-28T22:59:59Z", "2026-03-28"),
            ("2026-03-28T23:00:00Z", "2026-03-29"),
            ("2026-03-29T21:59:59Z", "2026-03-29"),
            ("2026-03-29T22:00:00Z", "2026-03-30"),
            ("2026-10-24T22:00:00Z", "2026-10-25"),
            ("2026-10-25T22:59:59Z", "2026-10-25"),
            ("2026-10-25T23:00:00Z", "2026-10-26"),
        ])
    func day(at moment: String, expected: String) throws {
        #expect(PuzzleCalendar.day(at: try .iso(moment)) == PuzzleDate(iso8601: expected))
    }

    @Test(
        "Next puzzle is at the next Amsterdam midnight, across clock changes",
        arguments: [
            // Winter time, UTC+1.
            ("2026-01-15T12:00:00Z", "2026-01-15T23:00:00Z"),
            // The day the clocks go forward is 23 hours long.
            ("2026-03-28T23:00:00Z", "2026-03-29T22:00:00Z"),
            ("2026-03-29T01:30:00Z", "2026-03-29T22:00:00Z"),
            // Summer time, UTC+2.
            ("2026-07-01T21:59:59Z", "2026-07-01T22:00:00Z"),
            // The day the clocks go back is 25 hours long.
            ("2026-10-24T22:00:00Z", "2026-10-25T23:00:00Z"),
            ("2026-10-25T00:30:00Z", "2026-10-25T23:00:00Z"),
            ("2026-10-25T01:30:00Z", "2026-10-25T23:00:00Z"),
        ])
    func nextPuzzle(after moment: String, expected: String) throws {
        #expect(PuzzleCalendar.nextPuzzle(after: try .iso(moment)) == (try .iso(expected)))
    }

    @Test("At midnight exactly, the next puzzle is a whole day away")
    func atMidnight() throws {
        let midnight = try Date.iso("2026-03-29T00:00:00+01:00")

        #expect(PuzzleCalendar.nextPuzzle(after: midnight) == (try .iso("2026-03-30T00:00:00+02:00")))
    }
}
