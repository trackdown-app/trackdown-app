import GameCore
import Observation

/// The Statistics sheet's state: the player's record at one network.
///
/// The record is worked out from the games kept on the device, so it is read again every time the sheet opens.
@MainActor
@Observable
public final class StatisticsModel {
    /// The network the record is for.
    public let network: Network

    /// The player's record at ``network``.
    public private(set) var statistics: Loadable<Statistics> = .loading

    @ObservationIgnored private let store: GameStore

    /// - Parameters:
    ///   - network: The network the record is for.
    ///   - store: Where the games are kept.
    public init(network: Network, store: GameStore) {
        self.network = network
        self.store = store
    }

    /// Loads the record. Call from the view's `.task`, and again to retry after it failed.
    public func load() async {
        guard statistics.value == nil else { return }
        statistics = .loading
        do {
            statistics = .loaded(try await store.statistics(network: network))
        } catch is CancellationError {
            return
        } catch {
            statistics = .failed(PlayingProblem(error))
        }
    }

    /// The network's name, for the sheet's title: "Your Netherlands record".
    public var networkName: String { network.name }

    /// The "Guesses needed" chart: one bar per guess count, then Missed. Today's game is highlighted once it is over.
    public var distribution: [DistributionBar] {
        guard let statistics = statistics.value else { return [] }
        return DistributionBar.bars(for: statistics, highlighted: statistics.today?.bucket)
    }
}
