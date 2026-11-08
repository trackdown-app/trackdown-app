/// The app's only way to send analytics. Nothing outside this package imports PostHog.
///
/// Named `AnalyticsClient` rather than `Analytics`: a type named after its module makes
/// `Analytics.X` ambiguous everywhere the module is imported.
@MainActor
public protocol AnalyticsClient: AnyObject {
    /// Sends `event` with `properties`. The super properties are added to every event.
    func capture(_ event: String, properties: [String: AnalyticsValue])

    /// Updates the consent property and opts in to capture only when consent is allowed.
    func setConsent(_ consent: AnalyticsConsent)
}

extension AnalyticsClient {
    public func capture(_ event: String) {
        capture(event, properties: [:])
    }
}

extension AnalyticsConfiguration {
    /// A PostHog client, or a client that sends nothing when no project token is configured.
    @MainActor
    public func makeClient(consent: AnalyticsConsent = .unanswered) -> any AnalyticsClient {
        isEnabled ? PostHogAnalytics(configuration: self, consent: consent) : DisabledAnalytics()
    }
}

/// Sends nothing. Used when no project token is configured.
@MainActor
public final class DisabledAnalytics: AnalyticsClient {
    public init() {}

    public func capture(_ event: String, properties: [String: AnalyticsValue]) {}

    public func setConsent(_ consent: AnalyticsConsent) {}
}
