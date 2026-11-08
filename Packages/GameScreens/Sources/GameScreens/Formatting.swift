import Foundation
import GameCore

extension PuzzleDate {
    /// The day as the playing screen's title: "Friday 6 November" in British English.
    ///
    /// The day is a calendar day, so it is formatted in Amsterdam, where puzzle days start, whatever the device's
    /// time zone.
    func title(locale: Locale = .autoupdatingCurrent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = PuzzleCalendar.timeZone
        // Noon, well clear of any clock change.
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let date = calendar.date(from: components) else { return iso8601 }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: PuzzleCalendar.timeZone)
            .weekday(.wide).day().month(.wide)
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
}
