import Foundation
import Observation

/// The player's versioned analytics choice, shared by Privacy settings and the consent prompt.
@MainActor
@Observable
public final class AnalyticsSettings {
    public let client: any AnalyticsClient
    public private(set) var consent: AnalyticsConsent

    @ObservationIgnored private let defaults: UserDefaults

    static let key = "analyticsConsent"

    public convenience init(configuration: AnalyticsConfiguration, defaults: UserDefaults = .standard) {
        self.init(defaults: defaults) { configuration.makeClient(consent: $0) }
    }

    /// Supplies the saved choice before constructing the client, including its automatic events.
    init(defaults: UserDefaults, makeClient: (AnalyticsConsent) -> any AnalyticsClient) {
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: Self.key)
        let consent: AnalyticsConsent
        if saved?["version"] as? Int == AnalyticsConsent.textVersion,
            let allowed = saved?["allowed"] as? Bool
        {
            consent = allowed ? .allowed : .declined
        } else {
            consent = .unanswered
        }
        self.consent = consent
        client = makeClient(consent)
    }

    /// A system toggle's binding. An unanswered choice appears off until the player opts in.
    public var sharesUsageData: Bool {
        get { consent == .allowed }
        set { setConsent(newValue ? .allowed : .declined) }
    }

    /// Stores the choice and applies it immediately, without waiting for navigation or a relaunch. An answer keeps
    /// the first-launch prompt from showing again.
    public func setConsent(_ consent: AnalyticsConsent) {
        self.consent = consent
        switch consent {
        case .unanswered:
            defaults.removeObject(forKey: Self.key)
        case .allowed, .declined:
            defaults.set(
                ["version": AnalyticsConsent.textVersion, "allowed": consent == .allowed], forKey: Self.key)
        }
        client.setConsent(consent)
    }
}
