import Foundation
import GameCore
import Testing

@testable import GameScreens

@MainActor
@Suite("Choose network model")
struct ChooseNetworkModelTests {
    let service = FakePuzzleService()

    func makeModel(current: Network = .nl, games: [GameKey: StoredGame] = [:]) -> ChooseNetworkModel {
        ChooseNetworkModel(current: current, store: GameStore(service: service, storage: MemoryGameStorage(games)))
    }

    @Test("Lists every playable network, the current one chosen and Great Britain new")
    func networks() {
        let model = makeModel(current: .gb)
        #expect(model.networks.map(\.network) == [.nl, .gb])
        #expect(model.networks.filter(\.isChosen).map(\.network) == [.gb])
        #expect(model.networks.filter(\.isNew).map(\.network) == [.gb])
        #expect(model.upcoming == [.be, .de, .ch, .jp])
    }

    @Test("Loads each network's own streak")
    func streaks() async {
        // Puzzles 141 and 142 solved on their day at the Dutch network; nothing played at the British one.
        let won = StoredGame(guesses: ["ut"], archive: false, outcome: .won)
        let model = makeModel(games: [
            GameKey(network: .nl, number: 141): won,
            GameKey(network: .nl, number: 142): won,
        ])
        await model.load()

        #expect(model.networks.first { $0.network == .nl }?.streak == 2)
        #expect(model.networks.first { $0.network == .gb }?.streak == 0)
    }

    @Test(
        "Search filters playable and upcoming networks by name or code",
        arguments: [
            ("brit", [Network.gb], [UpcomingNetwork]()),
            ("NL", [.nl], []),
            ("zwitser", [], []),
            ("switz", [], [.ch]),
            ("  ", [.nl, .gb], [.be, .de, .ch, .jp]),
        ])
    func search(query: String, networks: [Network], upcoming: [UpcomingNetwork]) {
        let model = makeModel()
        model.query = query
        #expect(model.networks.map(\.network) == networks)
        #expect(model.upcoming == upcoming)
        #expect(model.isEmpty == (networks.isEmpty && upcoming.isEmpty))
    }

    @Test("Notify me is remembered per network")
    func notify() {
        let model = makeModel()
        model.notify(.de)
        #expect(model.notified == [.de])
    }
}
