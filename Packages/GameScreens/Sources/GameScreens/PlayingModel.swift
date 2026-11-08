import DesignSystem
import Foundation
import GameCore
import Observation

/// Which puzzle a ``PlayingModel`` plays.
public enum PlayedPuzzle: Sendable, Hashable {
    /// Today's puzzle of the model's network. Follows the day rollover.
    case today
    /// A past puzzle, opened from the archive.
    case archive(ArchivedPuzzle)
}

/// Why the playing screen could not load, or a guess could not be sent.
public enum PlayingProblem: Sendable, Hashable {
    /// The device could not reach the server.
    case offline
    /// The server no longer accepts this version of the app.
    case updateRequired
    /// Too many calls; the server asks to wait `retryAfter` (its `Retry-After` header).
    case rateLimited(retryAfter: Duration)
    /// Anything else: a server error or an answer the app does not understand.
    case unavailable

    init(_ error: any Error) {
        switch error as? PuzzleServiceError {
        case .offline: self = .offline
        case .unknownClient: self = .updateRequired
        case .rateLimited(let retryAfter): self = .rateLimited(retryAfter: retryAfter)
        default: self = .unavailable
        }
    }
}

/// The inline message above the guess bar when a guess is refused.
public enum GuessMessage: Error, Sendable, Hashable {
    /// What was typed is not a station of the network.
    case unknownStation
    /// The station, named, was already guessed in this game.
    case alreadyGuessed(String)
    /// The guess could not be sent.
    case problem(PlayingProblem)
}

/// A guess the server accepted, for haptics. A new value every time.
public struct SubmittedGuess: Sendable, Hashable {
    /// Counts up with every accepted guess, so two guesses in a row are never equal.
    public var sequence: Int
    /// Whether the guess was the mystery station.
    public var solved: Bool
}

/// One row of the guess list.
public struct GuessRow: Sendable, Hashable, Identifiable {
    /// The guess's place in the game, from 1.
    public var number: Int
    public var code: StationCode
    public var station: String
    public var steps: [TripStep]
    /// Whether this guess was the mystery station.
    public var correct: Bool

    public var id: Int { number }
}

/// The playing screen's state: the game being played, the guess field and its suggestions.
///
/// Plays today's puzzle or, opened from the archive, a past one. Games themselves live in the ``GameStore``; the
/// model reads them from there, so a guess or a rollover shows up without the model copying any state.
@MainActor
@Observable
public final class PlayingModel {
    /// Where the screen stands while it loads.
    public enum LoadState: Sendable, Hashable {
        case loading
        case ready
        case failed(PlayingProblem)
    }

    /// The most suggestions shown above the guess bar.
    static let suggestionLimit = 5

    public let puzzle: PlayedPuzzle

    /// The network being played. Changing it loads that network's game when the view's task restarts.
    public var network: Network

    /// What the player has typed. Every change clears the message and highlights the best match.
    public var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            message = nil
            selection = suggestions.first { !$0.isDisabled }?.id
        }
    }

    /// The highlighted suggestion, guessed on return or Guess.
    public var selection: GuessSuggestion.ID?

    public private(set) var loadState: LoadState = .loading
    public private(set) var message: GuessMessage?
    public private(set) var isSubmitting = false
    /// The last accepted guess, for haptics.
    public private(set) var lastGuess: SubmittedGuess?

    @ObservationIgnored private let store: GameStore
    @ObservationIgnored private let service: any PuzzleService
    @ObservationIgnored private let locale: StationLocale
    private var stations: [StationCode: Station] = [:]
    private var search: StationSearch?
    private var stationsNetwork: Network?

    /// - Parameters:
    ///   - puzzle: Today's puzzle, or a past one from the archive.
    ///   - network: The network the puzzle belongs to.
    ///   - store: Where the game is kept.
    ///   - service: Where the station list comes from.
    ///   - locale: The language of station names.
    public init(
        puzzle: PlayedPuzzle = .today,
        network: Network,
        store: GameStore,
        service: any PuzzleService,
        locale: StationLocale = .device
    ) {
        self.puzzle = puzzle
        self.network = network
        self.store = store
        self.service = service
        self.locale = locale
    }

    // MARK: Game

    /// The game being played, once loaded.
    public var key: GameKey? {
        switch puzzle {
        case .today: store.today[network].map { GameKey(network: network, number: $0.number) }
        case .archive(let archived): GameKey(network: network, number: archived.number)
        }
    }

    public var game: Game? { key.flatMap { store.games[$0] } }

    /// The puzzle's day.
    public var date: PuzzleDate? {
        switch puzzle {
        case .today: store.today[network]?.date
        case .archive(let archived): archived.date
        }
    }

    /// The guess being made, from 1, or the last one once the game is over: the "guess 5" of "guess 5 of 6".
    public var currentGuess: Int {
        guard let game else { return 1 }
        return game.isOver ? max(game.guesses.count, 1) : min(game.guesses.count + 1, game.maxGuesses)
    }

    /// The answer of the finished game, once revealed.
    public var reveal: Reveal? { key.flatMap { store.reveals[$0] } }

    /// The mystery station's name, once the finished game is revealed.
    public var revealedStation: String? { reveal.map { name(of: $0.station) } }

    /// Every guess with its trip, newest first. Once the game is revealed, every change names its station.
    public var rows: [GuessRow] {
        guard let trips = game?.trips else { return [] }
        let revealed = reveal?.guesses
        return trips.enumerated().reversed().map { index, trip in
            var steps = trip.steps
            if let revealed, revealed.indices.contains(index), revealed[index].guess == trip.guess {
                steps = revealed[index].steps
            }
            return GuessRow(
                number: index + 1,
                code: trip.guess,
                station: name(of: trip.guess),
                steps: steps,
                correct: trip.correct
            )
        }
    }

    /// The display name of `code`, or the code itself while the station list is not loaded.
    public func name(of code: StationCode) -> String {
        stations[code]?.name ?? code.rawValue
    }

    // MARK: Loading

    /// Loads the station list and opens the game, replaying stored guesses. Call from the view's `.task(id:)` with
    /// the network, and again to retry after a failure.
    public func load() async {
        let network = network
        if stationsNetwork != network || loadState != .ready {
            loadState = .loading
        }
        do {
            async let stationList = loadStations(network: network)
            async let opened: Void = openGame(network: network)
            let (loaded, _) = try await (stationList, opened)
            guard network == self.network else { return }
            install(loaded, network: network)
            loadState = .ready
            await revealIfOver()
        } catch is CancellationError {
            return
        } catch {
            guard network == self.network else { return }
            loadState = .failed(PlayingProblem(error))
        }
    }

    /// Asks for the answer of a finished game, so every change can be named. Best effort: without it the trips keep
    /// their hidden changes, and the results sheet asks again.
    private func revealIfOver() async {
        guard let key, game?.isOver == true, reveal == nil else { return }
        _ = try? await store.reveal(key)
    }

    private func loadStations(network: Network) async throws -> [Station] {
        if stationsNetwork == network { return Array(stations.values) }
        return try await service.stations(network: network, locale: locale)
    }

    private func openGame(network: Network) async throws {
        switch puzzle {
        case .today:
            // The rollover task may have loaded it already.
            if let game = store.todaysGame(network: network), game.status != .restoring { return }
            try await store.loadToday(network: network)
        case .archive(let archived):
            if let game = store.games[GameKey(network: network, number: archived.number)],
                game.status != .restoring
            {
                return
            }
            try await store.openArchive(number: archived.number, network: network)
        }
    }

    private func install(_ list: [Station], network: Network) {
        guard stationsNetwork != network else { return }
        // The service sorts the list by name, the order equally good matches come back in.
        stations = Dictionary(list.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
        search = StationSearch(stations: list)
        stationsNetwork = network
    }

    // MARK: Guessing

    /// The stations matching ``query``, best first. Stations already guessed are shown but cannot be picked.
    public var suggestions: [GuessSuggestion] {
        let guessed = Set(game?.guesses ?? [])
        let matches = search?.matches(for: query, guessed: guessed, limit: Self.suggestionLimit) ?? []
        return matches.map { match in
            GuessSuggestion(
                id: match.station.code.rawValue,
                name: match.station.name,
                matchedRange: match.matchedRange,
                detail: match.station.province,
                isDisabled: match.isGuessed
            )
        }
    }

    /// Whether the guess bar takes guesses: the game is loaded and not over.
    public var canGuess: Bool {
        loadState == .ready && game?.status == .playing
    }

    /// Guesses the highlighted suggestion, or the station whose name was typed in full.
    ///
    /// A duplicate or unknown station is refused with a ``message`` and not sent.
    ///
    /// - Returns: Whether the game is over now, so the Solved sheet should open.
    @discardableResult
    public func guess() async -> Bool {
        guard let key, let game, !isSubmitting else { return false }
        guard game.status == .playing else { return game.isOver }

        let station: Station
        switch resolveGuess(in: game) {
        case nil: return false
        case .success(let resolved): station = resolved
        case .failure(let refusal):
            message = refusal
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let result = try await store.submit(station.code, to: key)
            lastGuess = SubmittedGuess(sequence: (lastGuess?.sequence ?? 0) + 1, solved: result.correct)
            query = ""
            return self.game?.isOver ?? false
        } catch GameError.alreadyGuessed {
            message = .alreadyGuessed(station.name)
        } catch GameError.gameOver {
            return true
        } catch GameError.guessInProgress {
            // The first submit is still on its way; this tap changes nothing.
        } catch is CancellationError {
            // The screen went away.
        } catch PuzzleServiceError.invalidInput {
            message = .unknownStation
        } catch {
            message = .problem(PlayingProblem(error))
        }
        return false
    }

    /// The station a guess is for, a refusal, or `nil` when nothing was typed.
    private func resolveGuess(in game: Game) -> Result<Station, GuessMessage>? {
        let guessed = Set(game.guesses)
        if let selection, let station = stations[StationCode(selection)], !guessed.contains(station.code) {
            return .success(station)
        }

        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return nil }

        let exact = stations.values.first {
            $0.name.compare(typed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if let exact {
            return guessed.contains(exact.code) ? .failure(.alreadyGuessed(exact.name)) : .success(exact)
        }
        // Every match is a station already guessed: say so, rather than "unknown".
        let matches = suggestions
        if let first = matches.first, matches.allSatisfy(\.isDisabled) {
            return .failure(.alreadyGuessed(first.name))
        }
        return .failure(.unknownStation)
    }
}
