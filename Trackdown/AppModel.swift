import GameCore
import Observation
import TrackdownAPI

/// App-wide state, injected into the view tree through the environment.
@Observable
final class AppModel {
    let configuration: AppConfiguration

    /// Every game on the device.
    let games: GameStore

    /// The network being played. Only the Dutch network for now.
    var network: Network = .nl

    init(configuration: AppConfiguration) {
        self.configuration = configuration
        games = GameStore(service: TrackdownPuzzleService(apiConfiguration: configuration.api))
    }
}
