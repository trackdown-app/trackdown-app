import Foundation
import GameCore
import Synchronization

/// A ``PuzzleService`` with a puzzle per day and a fixed mystery station, that records every guess call.
final class FakePuzzleService: PuzzleService {
    struct GuessCall: Sendable, Hashable {
        var guess: StationCode
        var earlierGuesses: [StationCode]
        var puzzle: Int
    }

    let answer: StationCode
    let maxGuesses: Int
    private let clock: FakeClock
    private let state = Mutex<State>(State())

    private struct State {
        var guessCalls: [GuessCall] = []
        var todayCalls = 0
        var revealCalls = 0
        var guessError: PuzzleServiceError?
        /// How far the server's clock is behind the device's.
        var clockLag: TimeInterval = 0
    }

    init(clock: FakeClock, answer: StationCode = "asd", maxGuesses: Int = 6) {
        self.clock = clock
        self.answer = answer
        self.maxGuesses = maxGuesses
    }

    var guessCalls: [GuessCall] { state.withLock { $0.guessCalls } }
    var todayCalls: Int { state.withLock { $0.todayCalls } }
    var revealCalls: Int { state.withLock { $0.revealCalls } }

    func failGuesses(with error: PuzzleServiceError?) {
        state.withLock { $0.guessError = error }
    }

    func lagBehind(by interval: TimeInterval) {
        state.withLock { $0.clockLag = interval }
    }

    /// Puzzle 1 is on 2026-01-01; one a day after that.
    static func number(of day: PuzzleDate) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .distantPast
        let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? start
        return (calendar.dateComponents([.day], from: start, to: date).day ?? 0) + 1
    }

    func today(network: Network) async throws -> Puzzle {
        let lag = state.withLock {
            $0.todayCalls += 1
            return $0.clockLag
        }
        let now = clock.now.addingTimeInterval(-lag)
        let day = PuzzleCalendar.day(at: now)
        return Puzzle(
            network: network,
            number: Self.number(of: day),
            date: day,
            maxGuesses: maxGuesses,
            nextPuzzleAt: PuzzleCalendar.nextPuzzle(after: now)
        )
    }

    func stations(network: Network, locale: StationLocale) async throws -> [Station] { [] }

    /// Puzzle 1 up to today's, one a day from 2026-01-01.
    func puzzles(network: Network) async throws -> [ArchivedPuzzle] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .distantPast
        let today = try await self.today(network: network).number
        return (1...today).map { number in
            let date = calendar.date(byAdding: .day, value: number - 1, to: start) ?? start
            let day = calendar.dateComponents([.year, .month, .day], from: date)
            return ArchivedPuzzle(
                number: number,
                date: PuzzleDate(year: day.year ?? 0, month: day.month ?? 0, day: day.day ?? 0)
            )
        }
    }

    func guess(
        _ guess: StationCode,
        earlierGuesses: [StationCode],
        puzzle: Int,
        network: Network
    ) async throws -> GuessResult {
        let error = state.withLock {
            $0.guessCalls.append(GuessCall(guess: guess, earlierGuesses: earlierGuesses, puzzle: puzzle))
            return $0.guessError
        }
        if let error { throw error }
        return GuessResult(
            guess: guess,
            correct: guess == answer,
            steps: Self.steps(for: guess),
            totalMinutes: Self.steps(for: guess).reduce(0) { $0 + $1.minutes },
            earlierTrips: earlierGuesses.map { EarlierTrip(guess: $0, steps: Self.steps(for: $0)) }
        )
    }

    func reveal(guesses: [StationCode], puzzle: Int, network: Network) async throws -> Reveal {
        state.withLock { $0.revealCalls += 1 }
        return Reveal(station: answer, solved: guesses.contains(answer), guesses: [])
    }

    /// A trip whose length depends on the station, so tests can tell trips apart.
    static func steps(for guess: StationCode) -> [TripStep] {
        guess == "asd" ? [] : [.ride(train: "IC", minutes: guess.rawValue.count * 10)]
    }
}

/// A clock that only moves when a test, or ``sleep(for:)``, moves it.
final class FakeClock: Sendable {
    private let state: Mutex<(now: Date, sleeps: [Duration], sleepsLeft: Int)>

    /// - Parameter sleepsLeft: How many sleeps return before the next one throws `CancellationError`, which ends
    ///   a rollover loop.
    init(_ now: Date, sleepsLeft: Int = .max) {
        state = Mutex((now, [], sleepsLeft))
    }

    var now: Date { state.withLock { $0.now } }

    /// Every duration slept, in order.
    var sleeps: [Duration] { state.withLock { $0.sleeps } }

    func advance(by interval: TimeInterval) {
        state.withLock { $0.now.addTimeInterval(interval) }
    }

    func sleep(for duration: Duration) throws {
        try state.withLock {
            guard $0.sleepsLeft > 0 else { throw CancellationError() }
            $0.sleepsLeft -= 1
            $0.sleeps.append(duration)
            let (seconds, attoseconds) = duration.components
            $0.now.addTimeInterval(TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18)
        }
    }
}

/// Games kept in memory.
final class MemoryGameStorage: GameStorage {
    private let games: Mutex<[GameKey: StoredGame]>

    init(_ games: [GameKey: StoredGame] = [:]) {
        self.games = Mutex(games)
    }

    func load(_ key: GameKey) -> StoredGame? { games.withLock { $0[key] } }

    func save(_ game: StoredGame, for key: GameKey) throws {
        games.withLock { $0[key] = game }
    }
}

extension Date {
    /// A moment written as ISO 8601 with an offset, such as `2026-03-29T00:00:00+01:00`.
    static func iso(_ string: String) throws -> Date {
        try Date(string, strategy: .iso8601)
    }
}
