import Foundation
import GameCore
import Observation

/// One past puzzle in the archive, with how far the player got.
public struct ArchiveRow: Sendable, Hashable, Identifiable {
    /// How far the player got with the puzzle.
    public enum Progress: Sendable, Hashable {
        /// No guess made yet.
        case notStarted
        /// Guesses made, the game still on: guess `currentGuess` of `maxGuesses` is next.
        case started(currentGuess: Int, maxGuesses: Int)
        /// Tracked down in `guesses` of `maxGuesses`.
        case solved(guesses: Int, maxGuesses: Int)
        /// Every guess used.
        case missed

        /// Whether the game is solved or out of guesses.
        public var isFinished: Bool {
            switch self {
            case .solved, .missed: true
            case .notStarted, .started: false
            }
        }
    }

    /// What tapping the row does.
    public enum Action: Sendable, Hashable {
        /// Goes back to today's puzzle on the playing screen.
        case continueToday
        /// Plays the past puzzle.
        case play(ArchivedPuzzle)
        /// Opens the finished game's Solved or Missed sheet.
        case results(GameKey)
    }

    public var key: GameKey
    public var puzzle: ArchivedPuzzle
    /// Whether this is today's puzzle.
    public var isToday: Bool
    public var progress: Progress
    /// The mystery station's name, only once the game is finished and revealed.
    public var station: String?

    public var id: Int { puzzle.number }

    /// Whether the game is solved or out of guesses.
    public var isFinished: Bool { progress.isFinished }

    public var action: Action {
        if isFinished { return .results(key) }
        return isToday ? .continueToday : .play(puzzle)
    }
}

/// The archive rows of one month, newest first.
public struct ArchiveMonth: Sendable, Hashable, Identifiable {
    public var year: Int
    public var month: Int
    public var rows: [ArchiveRow]

    public var id: Int { year * 100 + month }
}

/// The Archive screen's state: every puzzle of the network up to today's, grouped by month, with each game's
/// progress and, once finished, its mystery station.
@MainActor
@Observable
public final class ArchiveModel {
    public let network: Network

    /// The puzzles and what the device stored for each, as loaded.
    public private(set) var entries: Loadable<[ArchiveEntry]> = .loading

    @ObservationIgnored private let store: GameStore
    @ObservationIgnored private let service: any PuzzleService
    @ObservationIgnored private let locale: StationLocale
    private var stations: [StationCode: Station] = [:]
    /// Mystery stations looked up since the archive opened.
    private var revealed: [Int: StationCode] = [:]

    /// - Parameters:
    ///   - network: The network whose puzzles to list.
    ///   - store: Where the games are kept.
    ///   - service: Where the station list comes from.
    ///   - locale: The language of station names.
    public init(network: Network, store: GameStore, service: any PuzzleService, locale: StationLocale = .device) {
        self.network = network
        self.store = store
        self.service = service
        self.locale = locale
    }

    // MARK: Loading

    /// Loads the puzzles and station names, then names the station of every finished game. Call from the view's
    /// `.task`, and again to retry.
    public func load() async {
        if entries.value == nil { entries = .loading }
        async let names: Void = loadStations()
        do {
            entries = .loaded(try await store.archive(network: network))
        } catch is CancellationError {
            return
        } catch {
            if entries.value == nil { entries = .failed(PlayingProblem(error)) }
        }
        await names
        await revealFinished()
    }

    private func loadStations() async {
        guard stations.isEmpty else { return }
        // Best effort: without names the rows show station codes, as the playing screen does.
        guard let list = try? await service.stations(network: network, locale: locale) else { return }
        stations = Dictionary(list.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Looks up the station of every finished game not named yet, newest first. Best effort: stops at the first
    /// failure, such as being rate limited, and the rest stay unnamed until the archive opens again.
    private func revealFinished() async {
        for row in rows where row.isFinished && row.station == nil {
            guard !Task.isCancelled else { return }
            do {
                if let station = try await store.mysteryStation(row.key) {
                    revealed[row.puzzle.number] = station
                }
            } catch {
                return
            }
        }
    }

    // MARK: Rows

    /// Every puzzle, newest first.
    public var rows: [ArchiveRow] {
        guard let entries = entries.value else { return [] }
        let today = store.today[network]
        let maxGuesses = today?.maxGuesses ?? 6
        return entries.map { entry in
            let key = GameKey(network: network, number: entry.puzzle.number)
            let progress = progress(of: key, stored: entry.game, maxGuesses: maxGuesses)
            let code = store.reveals[key]?.station ?? entry.game?.station ?? revealed[entry.puzzle.number]
            return ArchiveRow(
                key: key,
                puzzle: entry.puzzle,
                isToday: entry.puzzle.number == today?.number,
                progress: progress,
                station: progress.isFinished ? code.map(name(of:)) : nil
            )
        }
    }

    /// ``rows`` by month, newest first.
    public var months: [ArchiveMonth] {
        var months: [ArchiveMonth] = []
        for row in rows {
            let date = row.puzzle.date
            if let last = months.last, last.year == date.year, last.month == date.month {
                months[months.count - 1].rows.append(row)
            } else {
                months.append(ArchiveMonth(year: date.year, month: date.month, rows: [row]))
            }
        }
        return months
    }

    /// The game's progress: from the open game when there is one, so a guess made since the archive loaded shows,
    /// otherwise from what is stored.
    private func progress(of key: GameKey, stored: StoredGame?, maxGuesses: Int) -> ArchiveRow.Progress {
        if let game = store.games[key], game.status != .restoring {
            switch game.status {
            case .solved: return .solved(guesses: game.guesses.count, maxGuesses: game.maxGuesses)
            case .lost: return .missed
            case .playing, .restoring:
                return game.guesses.isEmpty
                    ? .notStarted : .started(currentGuess: game.guesses.count + 1, maxGuesses: game.maxGuesses)
            }
        }
        let guesses = store.games[key]?.guesses ?? stored?.guesses ?? []
        switch stored?.outcome {
        case .won: return .solved(guesses: guesses.count, maxGuesses: maxGuesses)
        case .lost: return .missed
        case nil:
            return guesses.isEmpty
                ? .notStarted : .started(currentGuess: min(guesses.count + 1, maxGuesses), maxGuesses: maxGuesses)
        }
    }

    /// The display name of `code`, or the code itself while the station list is not loaded.
    private func name(of code: StationCode) -> String {
        stations[code]?.name ?? code.rawValue
    }
}
