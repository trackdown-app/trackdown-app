import GameCore

/// Safe puzzle metadata shared with the website. Never contains stations, trips or player text.
public struct PuzzleEventProperties: Sendable, Hashable {
    public let network: Network
    public let puzzleNumber: Int
    public let archive: Bool

    public init(network: Network, puzzleNumber: Int, archive: Bool) {
        self.network = network
        self.puzzleNumber = puzzleNumber
        self.archive = archive
    }

    var values: [String: AnalyticsValue] {
        ["network": .string(network.rawValue), "puzzle_number": .int(puzzleNumber), "archive": .bool(archive)]
    }
}

/// Every explicit app event. Names and properties of puzzle events match the website's events.ts.
public enum AnalyticsEvent: Sendable, Hashable {
    public enum ShareMethod: String, Sendable, Hashable, CaseIterable {
        case shared
        case copied
    }

    public enum Screen: String, Sendable, Hashable, CaseIterable {
        case playing
        case archive
        case chooseNetwork = "choose_network"
        case results
        case howToPlay = "how_to_play"
        case statistics
    }

    case puzzleStarted(PuzzleEventProperties)
    case guessMade(PuzzleEventProperties, guessNumber: Int)
    case puzzleSolved(PuzzleEventProperties, guessesUsed: Int)
    case puzzleMissed(PuzzleEventProperties, guessesUsed: Int)
    case resultShared(PuzzleEventProperties, method: ShareMethod)
    case archivePuzzlePlayed(PuzzleEventProperties)
    case screenViewed(Screen, network: Network)
    case networkChanged(from: Network, to: Network)
    case networkNotifyRequested(UpcomingNetwork)
    case howToPlayOpened(network: Network)

    public var name: String {
        switch self {
        case .puzzleStarted: "puzzle_started"
        case .guessMade: "guess_made"
        case .puzzleSolved: "puzzle_solved"
        case .puzzleMissed: "puzzle_missed"
        case .resultShared: "result_shared"
        case .archivePuzzlePlayed: "archive_puzzle_played"
        case .screenViewed: "$screen"
        case .networkChanged: "network_changed"
        case .networkNotifyRequested: "network_notify_requested"
        case .howToPlayOpened: "how_to_play_opened"
        }
    }

    public var properties: [String: AnalyticsValue] {
        switch self {
        case .puzzleStarted(let puzzle), .archivePuzzlePlayed(let puzzle):
            return puzzle.values
        case .guessMade(let puzzle, let number):
            return puzzle.values.merging(["guess_number": .int(number)]) { _, value in value }
        case .puzzleSolved(let puzzle, let count), .puzzleMissed(let puzzle, let count):
            return puzzle.values.merging(["guesses_used": .int(count)]) { _, value in value }
        case .resultShared(let puzzle, let method):
            return puzzle.values.merging(["method": .string(method.rawValue)]) { _, value in value }
        case .screenViewed(let screen, let network):
            return ["$screen_name": .string(screen.rawValue), "network": .string(network.rawValue)]
        case .networkChanged(let from, let to):
            return ["from_network": .string(from.rawValue), "network": .string(to.rawValue)]
        case .networkNotifyRequested(let network):
            return ["network": .string(network.rawValue)]
        case .howToPlayOpened(let network):
            return ["network": .string(network.rawValue)]
        }
    }
}
