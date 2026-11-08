import Foundation
import GameCore
import Observation

extension UpcomingNetwork {
    /// The country code in the badge, such as `BE`.
    public var code: String { rawValue.uppercased() }

    /// The country's name, such as "Belgium".
    public var name: String {
        switch self {
        case .be: String(localized: "Belgium", bundle: .module, comment: "Rail network still to come.")
        case .de: String(localized: "Germany", bundle: .module, comment: "Rail network still to come.")
        case .ch: String(localized: "Switzerland", bundle: .module, comment: "Rail network still to come.")
        case .jp: String(localized: "Japan", bundle: .module, comment: "Rail network still to come.")
        }
    }

    /// What the network will cover, such as "National rail".
    public var detail: String {
        switch self {
        case .be, .ch:
            String(
                localized: "National rail", bundle: .module,
                comment: "Under a rail network still to come: the trains it will cover.")
        case .de:
            String(
                localized: "Regional and long distance", bundle: .module,
                comment: "Under Germany in Coming next: the trains it will cover.")
        case .jp:
            String(
                localized: "JR and private lines", bundle: .module,
                comment: "Under Japan in Coming next: the trains it will cover.")
        }
    }
}

/// One playable network in the list.
public struct NetworkRow: Sendable, Hashable, Identifiable {
    public var network: Network
    /// Whether this is the network being played.
    public var isChosen: Bool
    /// The current streak, once loaded; `nil` while it loads or when it could not be loaded.
    public var streak: Int?

    public var id: Network { network }

    public var code: String { network.code }
    public var name: String { network.name }
    public var detail: String { network.detail }
    /// Whether the network gets a "New" badge.
    public var isNew: Bool { network.isNew }
}

/// The Choose network screen's state: every playable network with its streak, the networks still to come, and the
/// search that filters both.
@MainActor
@Observable
public final class ChooseNetworkModel {
    /// The network being played.
    public let current: Network

    /// What the player typed in the search field.
    public var query: String = ""

    /// Each network's current streak, once loaded.
    public private(set) var streaks: [Network: Int] = [:]

    /// The networks still to come the player asked to hear about, this launch.
    public private(set) var notified: Set<UpcomingNetwork> = []

    @ObservationIgnored private let store: GameStore

    public init(current: Network, store: GameStore) {
        self.current = current
        self.store = store
    }

    /// Loads every network's streak. Best effort: a network whose record cannot be loaded shows no
    /// streak. Call from the view's `.task`.
    public func load() async {
        // One network after the other: the store is main-actor, so child tasks would gain nothing but hops.
        for network in Network.allCases {
            guard !Task.isCancelled else { return }
            if let statistics = try? await store.statistics(network: network) {
                streaks[network] = statistics.currentStreak
            }
        }
    }

    /// The playable networks matching ``query``.
    public var networks: [NetworkRow] {
        Network.allCases
            .map { NetworkRow(network: $0, isChosen: $0 == current, streak: streaks[$0]) }
            .filter { matches(name: $0.name, code: $0.code, detail: $0.detail) }
    }

    /// The networks still to come matching ``query``.
    public var upcoming: [UpcomingNetwork] {
        UpcomingNetwork.allCases.filter { matches(name: $0.name, code: $0.code, detail: $0.detail) }
    }

    /// Whether nothing matches ``query``.
    public var isEmpty: Bool { networks.isEmpty && upcoming.isEmpty }

    /// The player asked to hear when `network` comes out.
    public func notify(_ network: UpcomingNetwork) {
        notified.insert(network)
    }

    private func matches(name: String, code: String, detail: String) -> Bool {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return name.range(of: typed, options: options) != nil
            || code.compare(typed, options: options) == .orderedSame
            || detail.range(of: typed, options: options) != nil
    }
}
