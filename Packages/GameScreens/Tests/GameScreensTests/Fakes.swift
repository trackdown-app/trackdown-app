import Foundation
import GameCore
import Synchronization

/// A ``PuzzleService`` with one puzzle, a fixed mystery station and a small station list.
final class FakePuzzleService: PuzzleService {
    static let stations = [
        Station(code: "asd", name: "Amsterdam Centraal", province: "Noord-Holland"),
        Station(code: "asdz", name: "Amsterdam Zuid", province: "Noord-Holland"),
        Station(code: "gn", name: "Groningen", province: "Groningen"),
        Station(code: "hlm", name: "Haarlem", province: "Noord-Holland"),
        Station(code: "mt", name: "Maastricht", province: "Limburg"),
        Station(code: "ut", name: "Utrecht Centraal", province: "Utrecht"),
        Station(code: "zl", name: "Zwolle", province: "Overijssel"),
    ]

    static let puzzle = Puzzle(
        network: .nl,
        number: 142,
        date: PuzzleDate(year: 2026, month: 11, day: 6),
        maxGuesses: 6,
        nextPuzzleAt: .distantFuture
    )

    let answer: StationCode
    private let state = Mutex<State>(State())

    private struct State {
        var guesses: [StationCode] = []
        var guessError: PuzzleServiceError?
        var todayError: PuzzleServiceError?
    }

    init(answer: StationCode = "ut") {
        self.answer = answer
    }

    /// Every station sent to the guess endpoint, in order.
    var guesses: [StationCode] { state.withLock { $0.guesses } }

    func failGuesses(with error: PuzzleServiceError?) {
        state.withLock { $0.guessError = error }
    }

    func failToday(with error: PuzzleServiceError?) {
        state.withLock { $0.todayError = error }
    }

    func today(network: Network) async throws -> Puzzle {
        if let error = state.withLock({ $0.todayError }) { throw error }
        return Self.puzzle
    }

    func stations(network: Network, locale: StationLocale) async throws -> [Station] {
        Self.stations
    }

    func puzzles(network: Network) async throws -> [ArchivedPuzzle] {
        [ArchivedPuzzle(number: 141, date: PuzzleDate(year: 2026, month: 11, day: 5))]
    }

    func guess(
        _ guess: StationCode,
        earlierGuesses: [StationCode],
        puzzle: Int,
        network: Network
    ) async throws -> GuessResult {
        let error = state.withLock { state -> PuzzleServiceError? in
            if let error = state.guessError { return error }
            state.guesses.append(guess)
            return nil
        }
        if let error { throw error }
        return GuessResult(
            guess: guess,
            correct: guess == answer,
            steps: trip(from: guess),
            totalMinutes: 30,
            earlierTrips: earlierGuesses.map { EarlierTrip(guess: $0, steps: trip(from: $0)) }
        )
    }

    func reveal(guesses: [StationCode], puzzle: Int, network: Network) async throws -> Reveal {
        Reveal(station: answer, solved: guesses.last == answer, guesses: [])
    }

    private func trip(from station: StationCode) -> [TripStep] {
        station == answer ? [] : [.ride(train: "IC", minutes: 30)]
    }
}

/// Keeps games in memory.
final class MemoryGameStorage: GameStorage {
    private let games = Mutex<[GameKey: StoredGame]>([:])

    init(_ games: [GameKey: StoredGame] = [:]) {
        self.games.withLock { $0 = games }
    }

    func load(_ key: GameKey) -> StoredGame? {
        games.withLock { $0[key] }
    }

    func save(_ game: StoredGame, for key: GameKey) throws {
        games.withLock { $0[key] = game }
    }
}
