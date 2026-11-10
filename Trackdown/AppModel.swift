import Analytics
import GameCore
import GameScreens
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
    /// Usage data preferences and legal links.
    case privacy
}

/// App-wide state, injected into the view tree through the environment.
@Observable
final class AppModel {
    let configuration: AppConfiguration

    /// Where analytics events go. PostHog, or nothing without a project token.
    var analytics: any AnalyticsClient { analyticsSettings.client }

    /// The persisted analytics choice, shared by every entry point to Privacy.
    let analyticsSettings: AnalyticsSettings

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
            let previous = playing.network
            playing.network = newValue
            networkChoice.network = newValue
            if previous != newValue { analytics.capture(.networkChanged(from: previous, to: newValue)) }
        }
    }

    init(configuration: AppConfiguration, networkChoice: NetworkChoice = NetworkChoice()) {
        self.configuration = configuration
        let analyticsSettings = AnalyticsSettings(configuration: configuration.analytics)
        self.analyticsSettings = analyticsSettings
        let service = TrackdownPuzzleService(apiConfiguration: configuration.api)
        let games = GameStore(service: service)
        self.service = service
        self.games = games
        self.networkChoice = networkChoice
        playing = PlayingModel(
            network: networkChoice.network, store: games, service: service, analytics: analyticsSettings.client)
    }

    /// The Solved or Missed sheet of the finished game `key`.
    func results(_ key: GameKey) -> ResultsModel {
        ResultsModel(key: key, store: games, service: service, analytics: analytics)
    }

    /// The player's record at the current network, for the Statistics sheet.
    func statistics() -> StatisticsModel {
        StatisticsModel(network: network, store: games)
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
        PlayingModel(puzzle: .archive(puzzle), network: network, store: games, service: service, analytics: analytics)
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
        analytics.capture(.networkNotifyRequested(network))
    }
}
