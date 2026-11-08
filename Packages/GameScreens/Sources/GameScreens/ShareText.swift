import Foundation
import GameCore

/// The text a player shares once a game is over: a header with the puzzle and the score, one line per wrong guess in
/// the order they were made, and a footer with a link to the game.
///
/// A port of the website's `shareText` (`src/lib/game/share-text.ts`, `docs/share.md`): the same text, character for
/// character, for the same game. It never names a station, so it never gives the answer away.
///
/// ```
/// Trackdown NL 142, 5/6
/// ●━━━━━━━━○━  2h25
/// ●━━━━━○━━    1h57
/// ●━           17m
/// ●━           13m
/// Tracked down in 5
/// https://trackdown.nl/en/nl
/// ```
enum ShareText {
    /// One stretch of line in the grid stands for this many minutes of riding.
    static let cellMinutes = 15

    private static let startMark = "●"
    private static let rideMark = "━"
    private static let changeMark = "○"

    /// The whole text of `game`, in `language`. `nil` while the game is on or its trips are not rebuilt.
    static func text(for game: Game, language: StationLocale) -> String? {
        guard let trips = game.trips, game.isOver else { return nil }
        let won = game.status == .solved
        let count = game.guesses.count
        // The same in every language, as on the website.
        let header =
            "Trackdown \(game.key.network.rawValue.uppercased()) \(game.key.number), "
            + "\(won ? String(count) : "X")/\(game.maxGuesses)"
        let footer =
            won
            ? string(
                LocalizedStringResource(
                    "Tracked down in \(count)", locale: language.locale, bundle: .module,
                    comment: "Shared result of a solved game. The argument is how many guesses it took."))
            : string(
                LocalizedStringResource(
                    "Not tracked down", locale: language.locale, bundle: .module,
                    comment: "Shared result of a game that ran out of guesses."))
        return
            ([header] + grid(trips, language: language) + [footer, url(network: game.key.network, language: language)])
            .joined(separator: "\n")
    }

    /// A time as the grid writes it: `2h25`, or `17m` under an hour. `2u25` in Dutch.
    static func minutes(_ minutes: Int, language: StationLocale) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        let rest = minutes % 60
        let padded = rest < 10 ? "0\(rest)" : "\(rest)"
        return string(
            LocalizedStringResource(
                "\(minutes / 60)h\(padded)", locale: language.locale, bundle: .module,
                comment:
                    "A trip time in a shared result, such as 2h25. The arguments are hours and the minutes, padded to two digits."
            ))
    }

    /// A trip as one run of characters: a dot for the guess, a stretch of line per ride (one per 15 minutes, at least
    /// one) and a ring per change. The change's station is never written, known or not.
    static func line(_ steps: [TripStep]) -> String {
        var line = startMark
        for step in steps {
            switch step {
            case .ride(_, let minutes):
                let cells = max(1, Int((Double(minutes) / Double(cellMinutes)).rounded(.toNearestOrAwayFromZero)))
                line += String(repeating: rideMark, count: cells)
            case .change:
                line += changeMark
            }
        }
        return line
    }

    /// Every wrong guess, oldest first: its line, then its time, the times lined up two spaces past the longest line.
    /// The correct guess has no trip, so it has no line; the footer counts it.
    static func grid(_ trips: [GuessTrip], language: StationLocale) -> [String] {
        let rows = trips.filter { !$0.correct }.map {
            (line: line($0.steps), time: minutes($0.totalMinutes, language: language))
        }
        let width = rows.map(\.line.count).max() ?? 0
        return rows.map { row in
            row.line + String(repeating: " ", count: width + 2 - row.line.count) + row.time
        }
    }

    /// The network's game in `language`, so a friend plays the same network's puzzle.
    static func url(network: Network, language: StationLocale) -> String {
        string(
            LocalizedStringResource(
                "https://trackdown.nl/en/\(network.rawValue)", locale: language.locale, bundle: .module,
                comment:
                    "Link at the end of a shared result: the network's game in the app's language. Dutch drops the /en. The argument is the network, such as nl."
            ))
    }

    private static func string(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }
}

extension StationLocale {
    /// The locale strings in this language are looked up in.
    var locale: Locale { Locale(identifier: rawValue) }
}
