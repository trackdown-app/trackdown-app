import Foundation

/// The puzzle day: a new puzzle comes out every midnight in Amsterdam, for every network.
///
/// The server's `nextPuzzleAt` is what the game follows. This calendar is the device's own view of the same
/// boundary, so a puzzle whose day has passed is replaced even when the device clock and `nextPuzzleAt` disagree.
public enum PuzzleCalendar {
    /// Europe/Amsterdam, where a puzzle day starts and ends.
    public static let timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .gmt

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The puzzle day `date` falls on.
    public static func day(at date: Date) -> PuzzleDate {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return PuzzleDate(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    /// When the puzzle day after the one `date` falls on starts: the next midnight in Amsterdam.
    ///
    /// Days are 23 or 25 hours long when the clocks change, so this is not `date` plus a day's worth of seconds.
    public static func nextPuzzle(after date: Date) -> Date {
        let calendar = calendar
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(24 * 60 * 60)
    }
}
