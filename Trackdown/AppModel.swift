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
    /// The last past puzzle's playing screen, reused while that puzzle stays open.
    @ObservationIgnored private var archivedPlaying: PlayingModel?

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

    /// A playing screen for a past puzzle of the current network. Asking again for the same puzzle returns the same
    /// model, so a guess being typed survives the switch between the stack and the split view when iPhone Duo opens
    /// or closes.
    func playing(_ puzzle: ArchivedPuzzle) -> PlayingModel {
        if let archivedPlaying, archivedPlaying.puzzle == .archive(puzzle), archivedPlaying.network == network {
            return archivedPlaying
        }
        let model = PlayingModel(
            puzzle: .archive(puzzle), network: network, store: games, service: service, analytics: analytics)
        archivedPlaying = model
        return model
    }

    // MARK: Split view

    // ``path`` stays the one record of where the player is. With the archive as a sidebar, the detail column's root is
    // the selected puzzle and its stack is what follows it in ``path``. The stack it collapses to when iPhone Duo
    // closes then still has the archive under a past puzzle, and Back goes there.

    /// Where the past puzzle open in the detail column sits in ``path``.
    private var detailPuzzleIndex: Int? {
        path.firstIndex { route in
            if case .archivedPuzzle = route { true } else { false }
        }
    }

    /// The past puzzle at the root of the detail column, or `nil` while it shows today's.
    var detailPuzzle: ArchivedPuzzle? {
        guard let index = detailPuzzleIndex, case .archivedPuzzle(let puzzle) = path[index] else { return nil }
        return puzzle
    }

    /// What the detail column's stack pushes on top of ``detailPuzzle`` or today's puzzle. Never the archive: the
    /// sidebar shows it instead.
    var detailPath: [Route] {
        get {
            guard let index = detailPuzzleIndex else { return path.filter { $0 != .archive } }
            return Array(path[(index + 1)...])
        }
        set {
            guard newValue != detailPath else { return }
            if let index = detailPuzzleIndex {
                path = Array(path[...index]) + newValue
            } else {
                path = newValue
            }
        }
    }

    /// Opens an archive sidebar row's puzzle in the detail column: today's on the playing screen, a past one,
    /// finished or not, as a past puzzle.
    func show(_ row: ArchiveRow) {
        let newPath: [Route] = row.isToday ? [] : [.archive, .archivedPuzzle(row.puzzle)]
        if path != newPath { path = newPath }
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

    /// Opens a website destination, leaving unavailable archive puzzles on today's screen.
    func open(_ link: PuzzleLink) async {
        switch link {
        case .today(let network):
            choose(network ?? self.network)
        case .archive(let network, let number):
            choose(network)
            guard let puzzles = try? await service.puzzles(network: network),
                !Task.isCancelled, self.network == network,
                let puzzle = puzzles.first(where: { $0.number == number })
            else { return }
            path = [.archivedPuzzle(puzzle)]
        }
    }

    /// The player tapped Notify me on a network still to come.
    func notify(_ network: UpcomingNetwork) {
        analytics.capture(.networkNotifyRequested(network))
    }
}
