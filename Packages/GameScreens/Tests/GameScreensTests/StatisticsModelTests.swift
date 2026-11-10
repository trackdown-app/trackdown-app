import Foundation
import GameCore
import Testing

@testable import GameScreens

@MainActor
@Suite("Statistics model")
struct StatisticsModelTests {
    let service = FakePuzzleService()
    let today = GameKey(network: .nl, number: 142)
    let yesterday = GameKey(network: .nl, number: 141)

    func makeStore(_ games: [GameKey: StoredGame] = [:]) -> GameStore {
        GameStore(service: service, storage: MemoryGameStorage(games))
    }

    @Test("Loads the record of its network from the games kept on the device")
    func loadsRecord() async throws {
        let store = makeStore([
            yesterday: StoredGame(guesses: ["mt", "ut"], archive: false, outcome: .won),
            today: StoredGame(guesses: ["mt", "hlm", "gn", "ut"], archive: false, outcome: .won),
        ])
        let model = StatisticsModel(network: .nl, store: store)
        #expect(model.statistics == .loading)
        #expect(model.distribution.isEmpty)

        await model.load()

        let statistics = try #require(model.statistics.value)
        #expect(statistics.played == 2)
        #expect(statistics.winPercent == 100)
        #expect(statistics.currentStreak == 2)
        #expect(statistics.bestStreak == 2)
        #expect(
            model.distribution.map(\.bucket) == [
                .guesses(1), .guesses(2), .guesses(3), .guesses(4), .guesses(5), .guesses(6), .missed,
            ])
        #expect(model.distribution.map(\.count) == [0, 1, 0, 1, 0, 0, 0])
        // No guess call: the record comes from storage alone.
        #expect(service.guesses.isEmpty)
    }

    @Test("Highlights today's game once it is over")
    func highlightsToday() async {
        let store = makeStore([
            yesterday: StoredGame(guesses: ["mt", "ut"], archive: false, outcome: .won),
            today: StoredGame(guesses: ["mt", "hlm", "gn", "ut"], archive: false, outcome: .won),
        ])
        let model = StatisticsModel(network: .nl, store: store)
        await model.load()

        #expect(model.distribution.filter(\.isHighlighted).map(\.bucket) == [.guesses(4)])
    }

    @Test("Highlights Missed when today's game ran out of guesses")
    func highlightsMissed() async {
        let store = makeStore([
            today: StoredGame(guesses: ["mt", "hlm", "gn", "zl", "asd", "asdz"], archive: false, outcome: .lost)
        ])
        let model = StatisticsModel(network: .nl, store: store)
        await model.load()

        #expect(model.statistics.value?.currentStreak == 0)
        #expect(model.distribution.filter(\.isHighlighted).map(\.bucket) == [.missed])
    }

    @Test("Highlights nothing while today's game is still on")
    func highlightsNothingWhilePlaying() async {
        let store = makeStore([
            yesterday: StoredGame(guesses: ["mt", "ut"], archive: false, outcome: .won),
            today: StoredGame(guesses: ["mt"], archive: false, outcome: nil),
        ])
        let model = StatisticsModel(network: .nl, store: store)
        await model.load()

        #expect(model.statistics.value?.played == 1)
        #expect(model.statistics.value?.currentStreak == 1)
        #expect(model.distribution.count == 7)
        #expect(model.distribution.filter(\.isHighlighted).isEmpty)
    }

    @Test("Shows zeros and seven empty bars before the first game")
    func emptyRecord() async throws {
        let model = StatisticsModel(network: .nl, store: makeStore())
        await model.load()

        let statistics = try #require(model.statistics.value)
        #expect(statistics.played == 0)
        #expect(statistics.winPercent == 0)
        #expect(model.distribution.count == 7)
        #expect(model.distribution.allSatisfy { $0.count == 0 && $0.fraction == 0 })
    }

    @Test("Keeps each network's record apart")
    func perNetwork() async {
        let store = makeStore([today: StoredGame(guesses: ["ut"], archive: false, outcome: .won)])
        let model = StatisticsModel(network: .gb, store: store)
        await model.load()

        #expect(model.statistics.value?.played == 0)
    }

    @Test("Says the record failed, and loads it on retry")
    func failsAndRetries() async {
        service.failToday(with: .offline)
        let model = StatisticsModel(network: .nl, store: makeStore())
        await model.load()

        #expect(model.statistics == .failed(.offline))
        #expect(model.distribution.isEmpty)

        service.failToday(with: nil)
        await model.load()
        #expect(model.statistics.value?.played == 0)
    }
}
