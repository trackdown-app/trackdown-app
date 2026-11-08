import Foundation
import GameCore

extension PuzzleDate {
    /// The day as the playing screen's title: "Friday 6 November" in British English.
    ///
    /// The day is a calendar day, so it is formatted in Amsterdam, where puzzle days start, whatever the device's
    /// time zone.
    func title(locale: Locale = .autoupdatingCurrent) -> String {
        formatted(locale: locale) { $0.weekday(.wide).day().month(.wide) }
    }

    /// The short weekday above the day in an archive row: "Fri".
    func shortWeekday(locale: Locale = .autoupdatingCurrent) -> String {
        formatted(locale: locale) { $0.weekday(.abbreviated) }
    }

    /// The month and year over a month of archive rows: "November 2026".
    func monthTitle(locale: Locale = .autoupdatingCurrent) -> String {
        formatted(locale: locale) { $0.month(.wide).year() }
    }

    /// The day formatted in Amsterdam, where puzzle days start, whatever the device's time zone.
    private func formatted(
        locale: Locale,
        _ fields: (Date.FormatStyle) -> Date.FormatStyle
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = PuzzleCalendar.timeZone
        // Noon, well clear of any clock change.
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let date = calendar.date(from: components) else { return iso8601 }
        var style = fields(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: PuzzleCalendar.timeZone))
        style.capitalizationContext = .beginningOfSentence
        return date.formatted(style)
    }
}

extension Duration {
    /// A `Retry-After` wait in words: "30 seconds", "2 minutes, 5 seconds".
    func retryText(locale: Locale = .autoupdatingCurrent) -> String {
        // Never "0 seconds": the server asked to wait, so round up to at least one.
        let wait = max(self, .seconds(1))
        return wait.formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide, fractionalPart: .hide(rounded: .up))
                .locale(locale))
    }
}

extension Network {
    /// The short code in the network pill's badge, such as `NL`.
    var code: String { rawValue.uppercased() }

    /// The network's name, such as "Netherlands".
    var name: String {
        switch self {
        case .nl: String(localized: "Netherlands", bundle: .module, comment: "Rail network name in the network pill.")
        case .gb:
            String(localized: "Great Britain", bundle: .module, comment: "Rail network name in the network pill.")
        }
    }

    /// What the network covers, such as "All railway stations".
    var detail: String {
        switch self {
        case .nl:
            String(
                localized: "All railway stations", bundle: .module,
                comment: "Under Netherlands in the network list: the stations the game covers.")
        case .gb:
            String(
                localized: "All National Rail stations", bundle: .module,
                comment: "Under Great Britain in the network list: the stations the game covers.")
        }
    }

    /// Whether the network is new, so the list marks it with a "New" badge.
    var isNew: Bool { self == .gb }
}
