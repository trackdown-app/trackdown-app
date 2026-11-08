import Foundation
import Observation

/// Why ``GameStore`` refused a guess.
public enum GameError: Error, Sendable, Hashable {
    /// The game was not opened with ``GameStore/loadToday(network:)`` or ``GameStore/openArchive(number:network:)``.
    case notOpened
    /// The game is solved or out of guesses.
    case gameOver
    /// The station was already guessed in this game.
    case alreadyGuessed
    /// Another guess on this game is still waiting for the server.
    case guessInProgress
}

/// Every game on the device: today's puzzle per network, archive games, their guesses and trips.
///
/// The server stores nothing, so the store keeps each game's guesses in a ``GameStorage`` and rebuilds the trips
/// by replaying the guesses through the guess endpoint when a game is opened.
@MainActor
@Observable
public final class GameStore {
    /// Today's puzzle per network, once loaded.
    public private(set) var today: [Network: Puzzle] = [:]

    /// Every game opened since launch.
    public private(set) var games: [GameKey: Game] = [:]

    /// The answer of every finished game revealed since launch. See ``reveal(_:)``.
    public private(set) var reveals: [GameKey: Reveal] = [:]

    /// How long ``followRollover(network:)`` waits before asking again when the server has no new puzzle yet,
    /// or could not be reached.
    public var retryDelay: Duration = .seconds(30)

    @ObservationIgnored private let service: any PuzzleService
    @ObservationIgnored private let storage: any GameStorage
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var guessing: Set<GameKey> = []

    /// - Parameters:
    ///   - service: Where puzzles and trips come from.
    ///   - storage: Where guesses are kept between launches.
    ///   - now: The current time, for the day rollover.
    ///   - sleep: Waits for a duration, for the day rollover. Throws `CancellationError` when cancelled.
    public init(
        service: any PuzzleService,
        storage: any GameStorage = FileGameStorage.applicationSupport,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.service = service
        self.storage = storage
        self.now = now
        self.sleep = sleep
    }

    /// Today's game of `network`, once ``loadToday(network:)`` has loaded it.
    public func todaysGame(network: Network) -> Game? {
        guard let puzzle = today[network] else { return nil }
        return games[GameKey(network: network, number: puzzle.number)]
    }

    /// Fetches today's puzzle of `network` and opens its game, restoring stored guesses and replaying them to
    /// rebuild their trips.
    ///
    /// When the replay fails the game is still opened, with its guesses and ``Game/Status/restoring`` status, and
    /// the error is thrown. Calling again retries the replay.
    @discardableResult
    public func loadToday(network: Network) async throws -> Game {
        let puzzle = try await service.today(network: network)
        today[network] = puzzle
        return try await open(
            GameKey(network: network, number: puzzle.number),
            maxGuesses: puzzle.maxGuesses,
            isArchive: false
        )
    }

    /// Opens puzzle `number` of `network` from the archive, to start it or carry on where it was left.
    ///
    /// Archive games are stored like today's, with `archive: true`. Opening today's puzzle this way opens today's
    /// game. Replay failures are handled as in ``loadToday(network:)``.
    @discardableResult
    public func openArchive(number: Int, network: Network) async throws -> Game {
        // Archive puzzles carry no limit of their own; the API's limit is the same for every puzzle.
        let puzzle: Puzzle
        if let known = today[network] {
            puzzle = known
        } else {
            puzzle = try await service.today(network: network)
            today[network] = puzzle
        }
        return try await open(
            GameKey(network: network, number: number),
            maxGuesses: puzzle.maxGuesses,
            isArchive: number != puzzle.number
        )
    }

    /// Submits `guess` to the game `key`, stores it and updates every trip from the server's answer.
    ///
    /// Throws a ``GameError`` when the guess is not allowed, or the ``PuzzleServiceError`` of the call. A guess the
    /// server rejects is not stored.
    @discardableResult
    public func submit(_ guess: StationCode, to key: GameKey) async throws -> GuessResult {
        guard let game = games[key] else { throw GameError.notOpened }
        guard !game.isOver, game.guessesLeft > 0 else { throw GameError.gameOver }
        guard !game.guesses.contains(guess) else { throw GameError.alreadyGuessed }
        guard guessing.insert(key).inserted else { throw GameError.guessInProgress }
        defer { guessing.remove(key) }

        let result = try await service.guess(
            guess,
            earlierGuesses: game.guesses,
            puzzle: key.number,
            network: key.network
        )

        var updated = games[key] ?? game
        updated.guesses = game.guesses + [guess]
        updated.trips = result.trips
        games[key] = updated
        persist(updated)
        return result
    }

    /// The mystery station of the finished game `key` and every guess's whole trip, with every change named.
    ///
    /// Asks the server once per game and keeps the answer in ``reveals`` for the rest of the launch. Throws
    /// ``GameError/notOpened`` for a game not opened, ``PuzzleServiceError/gameNotOver`` for a game still on, or the
    /// ``PuzzleServiceError`` of the call.
    @discardableResult
    public func reveal(_ key: GameKey) async throws -> Reveal {
        if let known = reveals[key] { return known }
        guard let game = games[key] else { throw GameError.notOpened }
        guard game.isOver else { throw PuzzleServiceError.gameNotOver }

        let reveal = try await service.reveal(guesses: game.guesses, puzzle: key.number, network: key.network)
        // The answer belongs to these guesses; a finished game takes no more, so they cannot have changed.
        reveals[key] = reveal
        return reveal
    }

    /// The player's record at `network`: fetches the archive and reads every puzzle's stored game. Needs no replay,
    /// since each finished game is stored with its outcome.
    public func statistics(network: Network) async throws -> Statistics {
        let puzzles = try await service.puzzles(network: network)
        let maxGuesses: Int
        if let known = today[network] {
            maxGuesses = known.maxGuesses
        } else {
            let puzzle = try await service.today(network: network)
            today[network] = puzzle
            maxGuesses = puzzle.maxGuesses
        }
        var games: [Int: StoredGame] = [:]
        for puzzle in puzzles {
            games[puzzle.number] = storage.load(GameKey(network: network, number: puzzle.number))
        }
        return Statistics(puzzles: puzzles, games: games, maxGuesses: maxGuesses)
    }

    /// Loads today's puzzle again when its day is over: once `nextPuzzleAt` has passed, or the Amsterdam calendar
    /// says a new day has started. Call it when the app comes to the foreground.
    ///
    /// - Returns: Whether a different puzzle is today's now.
    @discardableResult
    public func rolloverIfNeeded(network: Network) async throws -> Bool {
        let previous = today[network]
        if let previous, !isOver(previous) { return false }
        try await loadToday(network: network)
        return today[network]?.number != previous?.number
    }

    /// Keeps today's puzzle of `network` current while the app runs: waits until `nextPuzzleAt`, then loads the
    /// new puzzle. Returns once its task is cancelled, so run it in a view's `.task { }`.
    ///
    /// When the server still answers with the old puzzle (its clock is behind the device's) or cannot be reached,
    /// it asks again after ``retryDelay``.
    public func followRollover(network: Network) async {
        while !Task.isCancelled {
            if let puzzle = today[network] {
                let wait = puzzle.nextPuzzleAt.timeIntervalSince(now())
                if wait > 0 {
                    do { try await sleep(.seconds(wait)) } catch { return }
                }
            }

            let rolledOver: Bool
            do {
                rolledOver = try await rolloverIfNeeded(network: network)
            } catch is CancellationError {
                return
            } catch {
                rolledOver = false
            }

            // Woke early, for example after the app rolled over on its own when it came to the foreground.
            if !rolledOver, let puzzle = today[network], !isOver(puzzle) { continue }

            if !rolledOver {
                do { try await sleep(retryDelay) } catch { return }
            }
        }
    }

    /// Whether `puzzle`'s day is over.
    private func isOver(_ puzzle: Puzzle) -> Bool {
        let now = now()
        return now >= puzzle.nextPuzzleAt || PuzzleCalendar.day(at: now) > puzzle.date
    }

    private func open(_ key: GameKey, maxGuesses: Int, isArchive: Bool) async throws -> Game {
        var game: Game
        if let existing = games[key] {
            game = existing
            game.maxGuesses = maxGuesses
        } else if let stored = storage.load(key) {
            game = Game(
                key: key,
                maxGuesses: maxGuesses,
                isArchive: stored.archive,
                guesses: stored.guesses,
                trips: stored.guesses.isEmpty ? [] : nil
            )
        } else {
            game = Game(key: key, maxGuesses: maxGuesses, isArchive: isArchive)
        }
        games[key] = game

        guard game.trips == nil, let last = game.guesses.last else { return game }

        // One guess call rebuilds every trip: the answer carries the earlier guesses' trips too.
        let result = try await service.guess(
            last,
            earlierGuesses: Array(game.guesses.dropLast()),
            puzzle: key.number,
            network: key.network
        )

        // A guess made while the replay was in flight already rebuilt the trips; keep those.
        guard var current = games[key], current.guesses == game.guesses else { return games[key] ?? game }
        current.trips = result.trips
        games[key] = current
        // A game stored without its outcome (finished before outcomes were kept) gets it now, so the statistics count it.
        if storage.load(key)?.outcome != current.stored.outcome {
            persist(current)
        }
        return current
    }

    private func persist(_ game: Game) {
        // Best effort: a failed write keeps the game in memory for this launch. Storage errors are rare (a full
        // disk) and there is nothing better to do mid-game.
        try? storage.save(game.stored, for: game.key)
    }
}
