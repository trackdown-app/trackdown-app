import GameCore
import GameScreens
import Observation
import TrackdownAPI

/// A screen pushed onto the main navigation stack.
enum Route: Hashable {
    /// A past puzzle, played on the playing screen.
    case archivedPuzzle(ArchivedPuzzle)
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

    /// The network being played. Only the Dutch network for now.
    var network: Network {
        get { playing.network }
        set { playing.network = newValue }
    }

    init(configuration: AppConfiguration) {
        self.configuration = configuration
        let service = TrackdownPuzzleService(apiConfiguration: configuration.api)
        let games = GameStore(service: service)
        self.service = service
        self.games = games
        playing = PlayingModel(network: .nl, store: games, service: service)
    }

    /// A playing screen for a past puzzle of the current network.
    func playing(_ puzzle: ArchivedPuzzle) -> PlayingModel {
        PlayingModel(puzzle: .archive(puzzle), network: network, store: games, service: service)
    }
}
