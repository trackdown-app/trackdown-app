import GameCore
import GameScreens
import OSLog
import Observation
import TrackdownAPI

/// A screen pushed onto the main navigation stack.
enum Route: Hashable {
    /// The archive of past puzzles.
    case archive
    /// A past puzzle, played on the playing screen.
    case archivedPuzzle(ArchivedPuzzle)
    /// The network picker.
    case chooseNetwork
}

/// App-wide state, injected into the view tree through the environment.
@Observable
final class AppModel {
    let configuration: AppConfiguration

    /// Where puzzles, stations and trips come from.
    let service: TrackdownPuzzleService

    /// Every game on the device.
    let games: GameStore

    /// Today's game on the playing screen.
    let playing: PlayingModel

    /// The main navigation stack.
    var path: [Route] = []

    @ObservationIgnored private let networkChoice: NetworkChoice

    /// The network being played, kept for the next launch.
    var network: Network {
        get { playing.network }
        set {
            playing.network = newValue
            networkChoice.network = newValue
        }
    }

    init(configuration: AppConfiguration, networkChoice: NetworkChoice = NetworkChoice()) {
        self.configuration = configuration
        let service = TrackdownPuzzleService(apiConfiguration: configuration.api)
        let games = GameStore(service: service)
        self.service = service
        self.games = games
        self.networkChoice = networkChoice
        playing = PlayingModel(network: networkChoice.network, store: games, service: service)
    }

    /// The Solved or Missed sheet of the finished game `key`.
    func results(_ key: GameKey) -> ResultsModel {
        ResultsModel(key: key, store: games, service: service)
    }

    /// The archive of the current network.
    func archive() -> ArchiveModel {
        ArchiveModel(network: network, store: games, service: service)
    }

    /// Pushes the archive, or goes back to it when it is already on the stack, so playing a past puzzle and
    /// opening the archive again does not stack a second one.
    func openArchive() {
        if let index = path.lastIndex(of: .archive) {
            path.removeSubrange((index + 1)...)
        } else {
            path.append(.archive)
        }
    }

    /// A playing screen for a past puzzle of the current network.
    func playing(_ puzzle: ArchivedPuzzle) -> PlayingModel {
        PlayingModel(puzzle: .archive(puzzle), network: network, store: games, service: service)
    }

    /// The network picker, with the current network checked.
    func chooseNetwork() -> ChooseNetworkModel {
        ChooseNetworkModel(current: network, store: games)
    }

    /// Switches the game to `network` and goes back to its playing screen.
    func choose(_ network: Network) {
        self.network = network
        path = []
    }

    /// The player tapped Notify me on a network still to come.
    func notify(_ network: UpcomingNetwork) {
        // v1 only records the interest. Sent to PostHog once analytics is in (#15, #28).
        Self.logger.info("network_notify_requested network=\(network.rawValue, privacy: .public)")
    }

    private static let logger = Logger(subsystem: "nl.trackdown", category: "analytics")
}
