/// Properties added to every event, including the SDK's own lifecycle events.
public struct SuperProperties: Sendable, Equatable {
    public var environment: AnalyticsEnvironment
    public var appVersion: String
    public var consent: AnalyticsConsent

    public init(environment: AnalyticsEnvironment, appVersion: String, consent: AnalyticsConsent) {
        self.environment = environment
        self.appVersion = appVersion
        self.consent = consent
    }

    /// The properties by name. `consent_marketing` is always `false`, as on the website, which has
    /// no marketing consent either.
    public var values: [String: AnalyticsValue] {
        [
            "environment": .string(environment.rawValue),
            "platform": "ios",
            "app_version": .string(appVersion),
            "consent_analytics": consent.propertyValue,
            "consent_marketing": false,
            "consent_version": .int(AnalyticsConsent.textVersion),
        ]
    }
}
