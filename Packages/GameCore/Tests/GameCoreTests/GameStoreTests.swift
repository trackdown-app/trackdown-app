import Foundation
import GameCore
import Testing

@MainActor
struct GameStoreTests {
    private let clock: FakeClock
    private let service: FakePuzzleService
    private let storage = MemoryGameStorage()

    init() throws {
        clock = FakeClock(try .iso("2026-03-10T12:00:00+01:00"))
        service = FakePuzzleService(clock: clock, answer: "asd", maxGuesses: 4)
    }

    private func makeStore() -> GameStore {
        let clock = clock
        return GameStore(service: service, storage: storage, now: { clock.now }, sleep: { try clock.sleep(for: $0) })
    }

    private var todaysKey: GameKey {
        GameKey(network: .nl, number: FakePuzzleService.number(of: PuzzleCalendar.day(at: clock.now)))
    }

    @Test("Opens a new game for today's puzzle, with the API's guess limit")
    func newGame() async throws {
        let store = makeStore()

        let game = try await store.loadToday(network: .nl)

        #expect(game.key == todaysKey)
        #expect(game.maxGuesses == 4)
        #expect(game.guesses.isEmpty)
        #expect(game.status == .playing)
        #expect(!game.isArchive)
        #expect(store.todaysGame(network: .nl) == game)
        #expect(service.guessCalls.isEmpty)
    }

    @Test("Stores each guess and rebuilds every trip from the answer")
    func submit() async throws {
        let store = makeStore()
        try await store.loadToday(network: .nl)

        try await store.submit("ut", to: todaysKey)
        try await store.submit("gvc", to: todaysKey)

        let game = try #require(store.games[todaysKey])
        #expect(game.guesses == ["ut", "gvc"])
        #expect(
            game.trips == [
                GuessTrip(guess: "ut", correct: false, steps: FakePuzzleService.steps(for: "ut")),
                GuessTrip(guess: "gvc", correct: false, steps: FakePuzzleService.steps(for: "gvc")),
            ])
        #expect(game.guessesLeft == 2)
        #expect(storage.load(todaysKey) == StoredGame(guesses: ["ut", "gvc"]))
        #expect(service.guessCalls.last?.earlierGuesses == ["ut"])
    }

    @Test("Restores today's game after a relaunch, replaying its guesses in one call")
    func restores() async throws {
        let first = makeStore()
        try await first.loadToday(network: .nl)
        try await first.submit("ut", to: todaysKey)
        try await first.submit("gvc", to: todaysKey)

        let relaunched = makeStore()
        let game = try await relaunched.loadToday(network: .nl)

        #expect(game.guesses == ["ut", "gvc"])
        #expect(game.trips?.map(\.guess) == ["ut", "gvc"])
        #expect(game.status == .playing)
        #expect(
            service.guessCalls.last
                == FakePuzzleService.GuessCall(guess: "gvc", earlierGuesses: ["ut"], puzzle: todaysKey.number))
        #expect(service.guessCalls.count == 3)
    }

    @Test("A restored game knows it was solved")
    func restoresSolved() async throws {
        try storage.save(StoredGame(guesses: ["ut", "asd"]), for: todaysKey)

        let game = try await makeStore().loadToday(network: .nl)

        #expect(game.status == .solved)
        #expect(game.isOver)
    }

    @Test("A game is lost once every guess is used")
    func lost() async throws {
        try storage.save(StoredGame(guesses: ["ut", "gvc", "ht"]), for: todaysKey)
        let store = makeStore()
        try await store.loadToday(network: .nl)

        try await store.submit("rtd", to: todaysKey)

        #expect(store.games[todaysKey]?.status == .lost)
        await #expect(throws: GameError.gameOver) { try await store.submit("asd", to: todaysKey) }
    }

    @Test("Refuses a guess on a solved game, a repeated station and a game not opened")
    func refuses() async throws {
        let store = makeStore()
        await #expect(throws: GameError.notOpened) { try await store.submit("ut", to: todaysKey) }

        try await store.loadToday(network: .nl)
        try await store.submit("ut", to: todaysKey)
        await #expect(throws: GameError.alreadyGuessed) { try await store.submit("ut", to: todaysKey) }

        try await store.submit("asd", to: todaysKey)
        await #expect(throws: GameError.gameOver) { try await store.submit("gvc", to: todaysKey) }
        #expect(store.games[todaysKey]?.guesses == ["ut", "asd"])
    }

    @Test("Does not store a guess the server rejects")
    func rejected() async throws {
        let store = makeStore()
        try await store.loadToday(network: .nl)
        service.failGuesses(with: .invalidInput)

        await #expect(throws: PuzzleServiceError.invalidInput) { try await store.submit("xyz", to: todaysKey) }

        #expect(store.games[todaysKey]?.guesses == [])
        #expect(storage.load(todaysKey) == nil)
    }

    @Test("Keeps the guesses of a game it cannot replay, and replays them on the next try")
    func replayFails() async throws {
        try storage.save(StoredGame(guesses: ["ut"]), for: todaysKey)
        service.failGuesses(with: .offline)
        let store = makeStore()

        await #expect(throws: PuzzleServiceError.offline) { try await store.loadToday(network: .nl) }
        #expect(store.games[todaysKey]?.status == .restoring)
        #expect(store.games[todaysKey]?.guesses == ["ut"])

        service.failGuesses(with: nil)
        let game = try await store.loadToday(network: .nl)
        #expect(game.status == .playing)
        #expect(game.trips?.map(\.guess) == ["ut"])
    }

    @Test("Stores an archive game with archive true and resumes it after a relaunch")
    func archive() async throws {
        let key = GameKey(network: .nl, number: 3)
        let first = makeStore()

        let started = try await first.openArchive(number: 3, network: .nl)
        try await first.submit("ut", to: key)

        #expect(started.isArchive)
        #expect(started.maxGuesses == 4)
        #expect(storage.load(key) == StoredGame(guesses: ["ut"], archive: true))

        let relaunched = makeStore()
        let resumed = try await relaunched.openArchive(number: 3, network: .nl)
        #expect(resumed.isArchive)
        #expect(resumed.trips?.map(\.guess) == ["ut"])

        try await relaunched.submit("asd", to: key)
        #expect(relaunched.games[key]?.status == .solved)
        #expect(storage.load(key) == StoredGame(guesses: ["ut", "asd"], archive: true))
    }

    @Test("Opening today's puzzle from the archive opens today's game")
    func archiveOfToday() async throws {
        let store = makeStore()
        try await store.loadToday(network: .nl)

        let game = try await store.openArchive(number: todaysKey.number, network: .nl)

        #expect(!game.isArchive)
    }

    @Test("Picks up the new puzzle on foreground only once its day is over")
    func rolloverIfNeeded() async throws {
        let store = makeStore()
        try await store.loadToday(network: .nl)
        let firstKey = todaysKey

        #expect(try await store.rolloverIfNeeded(network: .nl) == false)
        #expect(service.todayCalls == 1)

        clock.advance(by: 12 * 60 * 60)

        #expect(try await store.rolloverIfNeeded(network: .nl))
        #expect(store.todaysGame(network: .nl)?.key.number == firstKey.number + 1)
    }
}
