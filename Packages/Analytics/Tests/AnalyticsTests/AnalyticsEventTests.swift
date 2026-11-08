import Analytics
import GameCore
import Testing

@Suite("Typed analytics events")
struct AnalyticsEventTests {
    static let puzzle = PuzzleEventProperties(network: .nl, puzzleNumber: 141, archive: true)

    @Test(
        "Puzzle events match the web contract exactly",
        arguments: [
            (AnalyticsEvent.puzzleStarted(puzzle), "puzzle_started", [String: AnalyticsValue]()),
            (.guessMade(puzzle, guessNumber: 2), "guess_made", ["guess_number": .int(2)]),
            (.puzzleSolved(puzzle, guessesUsed: 3), "puzzle_solved", ["guesses_used": .int(3)]),
            (.puzzleMissed(puzzle, guessesUsed: 6), "puzzle_missed", ["guesses_used": .int(6)]),
            (.resultShared(puzzle, method: .shared), "result_shared", ["method": .string("shared")]),
            (.resultShared(puzzle, method: .copied), "result_shared", ["method": .string("copied")]),
            (.archivePuzzlePlayed(puzzle), "archive_puzzle_played", [:]),
        ])
    func puzzleContract(event: AnalyticsEvent, name: String, extra: [String: AnalyticsValue]) {
        let expected: [String: AnalyticsValue] = ["network": "nl", "puzzle_number": 141, "archive": true]
        #expect(event.name == name)
        #expect(event.properties == expected.merging(extra) { _, value in value })
    }

    @Test("Daily events retain the network and false archive flag", arguments: Network.allCases)
    func dailyProperties(network: Network) {
        let event = AnalyticsEvent.puzzleStarted(
            PuzzleEventProperties(network: network, puzzleNumber: 142, archive: false))
        #expect(event.properties == ["network": .string(network.rawValue), "puzzle_number": 142, "archive": false])
    }

    @Test("Screen views use PostHog's screen convention", arguments: AnalyticsEvent.Screen.allCases)
    func screenViews(screen: AnalyticsEvent.Screen) {
        let event = AnalyticsEvent.screenViewed(screen, network: .gb)
        #expect(event.name == "$screen")
        #expect(event.properties == ["$screen_name": .string(screen.rawValue), "network": "gb"])
    }

    @Test("Network changes contain only the previous and chosen network")
    func networkChanged() {
        let event = AnalyticsEvent.networkChanged(from: .nl, to: .gb)
        #expect(event.name == "network_changed")
        #expect(event.properties == ["from_network": "nl", "network": "gb"])
    }

    @Test("Notify requests contain only a supported upcoming network", arguments: UpcomingNetwork.allCases)
    func notifyRequested(network: UpcomingNetwork) {
        let event = AnalyticsEvent.networkNotifyRequested(network)
        #expect(event.name == "network_notify_requested")
        #expect(event.properties == ["network": .string(network.rawValue)])
    }

    @Test("Opening How to play contains only the current network")
    func howToPlayOpened() {
        let event = AnalyticsEvent.howToPlayOpened(network: .nl)
        #expect(event.name == "how_to_play_opened")
        #expect(event.properties == ["network": "nl"])
    }
}
