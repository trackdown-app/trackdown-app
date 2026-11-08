import Foundation

/// The network the player chose last, kept between launches.
///
/// Defaults to the Dutch network until the player picks another one, and when the stored value is not a network
/// this version knows.
public struct NetworkChoice {
    /// The `UserDefaults` key the choice is stored under.
    static let key = "chosenNetwork"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The chosen network. Setting it stores it.
    public var network: Network {
        get { defaults.string(forKey: Self.key).flatMap(Network.init(rawValue:)) ?? .nl }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.key) }
    }
}
