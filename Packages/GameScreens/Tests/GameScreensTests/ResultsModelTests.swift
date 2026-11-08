import Foundation
import GameCore
import Testing

@testable import GameScreens

@MainActor
@Suite("Results model")
struct ResultsModelTests {
    let service = FakePuzzleService()
    let key = GameKey(network: .nl, number: 142)

    /// A store with today's game played: `guesses` sent one by one.
    func makeStore(guesses: [StationCode]) async throws -> GameStore {
        let store = GameStore(service: service, storage: MemoryGameStorage())
        try await store.loadToday(network: .nl)
        for guess in guesses {
            try await store.submit(guess, to: key)
        }
        return store
    }

    @Test("A solved game: how many guesses, the station, and its bucket highlighted")
    func solved() async throws {
        let store = try await makeStore(guesses: ["mt", "hlm", "ut"])
        let model = ResultsModel(key: key, store: store, service: service, locale: .en)
        await model.load()

        #expect(model.outcome == .solved(guesses: 3, maxGuesses: 6))
        #expect(model.stationName == "Utrecht Centraal")
        #expect(model.closestGuess == nil)
        #expect(model.statistics.value?.played == 1)
        let bars = model.distribution
        #expect(
            bars.map(\.bucket) == [
                .guesses(1), .guesses(2), .guesses(3), .guesses(4), .guesses(5), .guesses(6), .missed,
            ])
        #expect(bars.filter(\.isHighlighted).map(\.bucket) == [.guesses(3)])
        #expect(bars.first { $0.bucket == .guesses(3) }?.fraction == 1)
        #expect(model.shareText?.hasPrefix("Trackdown NL 142, 3/6\n") == true)
        #expect(model.shareText?.hasSuffix("Tracked down in 3\nhttps://trackdown.nl/en/nl") == true)
    }

    @Test("A missed game: the closest guess and Missed highlighted")
    func missed() async throws {
        let store = try await makeStore(guesses: ["mt", "hlm", "gn", "zl", "asd", "asdz"])
        let model = ResultsModel(key: key, store: store, service: service, locale: .en)
        await model.load()

        #expect(model.outcome == .missed)
        #expect(model.stationName == "Utrecht Centraal")
        // Every fake trip is 30 minutes; the earliest wins a tie.
        #expect(model.closestGuess == ClosestGuess(station: "Maastricht", minutes: 30))
        #expect(model.distribution.filter(\.isHighlighted).map(\.bucket) == [.missed])
        #expect(model.shareText?.contains("X/6") == true)
    }

    @Test("Puts the answer in the store, so the playing screen names the station")
    func revealsForThePlayingScreen() async throws {
        let store = try await makeStore(guesses: ["ut"])
        let playing = PlayingModel(network: .nl, store: store, service: service, locale: .en)
        await playing.load()

        #expect(playing.revealedStation == "Utrecht Centraal")
    }

    @Test("Says the reveal failed, and loads it on retry")
    func revealFails() async throws {
        let store = try await makeStore(guesses: ["ut"])
        service.failReveals(with: .offline)
        let model = ResultsModel(key: key, store: store, service: service, locale: .en)
        await model.load()

        #expect(model.reveal == .failed(.offline))
        #expect(model.stationName == nil)

        service.failReveals(with: nil)
        await model.load()
        #expect(model.stationName == "Utrecht Centraal")
    }

    @Test("Has no newer puzzle while today's game is still today's")
    func noNewerPuzzle() async throws {
        let store = try await makeStore(guesses: ["ut"])
        let model = ResultsModel(key: key, store: store, service: service, locale: .en)

        #expect(!model.hasNewerPuzzle)
        #expect(model.nextPuzzleAt == FakePuzzleService.puzzle.nextPuzzleAt)
    }
}
