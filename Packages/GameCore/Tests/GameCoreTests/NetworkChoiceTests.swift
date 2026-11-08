import Foundation
import Testing

@testable import GameCore

@Suite("Network choice")
struct NetworkChoiceTests {
    let defaults: UserDefaults

    init() throws {
        let suite = "NetworkChoiceTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("Defaults to the Dutch network")
    func defaultsToNetherlands() {
        #expect(NetworkChoice(defaults: defaults).network == .nl)
    }

    @Test("Keeps the chosen network for the next launch")
    func persists() {
        NetworkChoice(defaults: defaults).network = .gb
        #expect(NetworkChoice(defaults: defaults).network == .gb)
    }

    @Test("Falls back to the Dutch network for a network this version does not know")
    func unknownValue() {
        defaults.set("be", forKey: NetworkChoice.key)
        #expect(NetworkChoice(defaults: defaults).network == .nl)
    }
}
