import Foundation

/// Settings for the PostHog-backed analytics client.
public struct AnalyticsConfiguration: Sendable, Equatable {
    /// PostHog project token. Empty means analytics is off.
    public var projectToken: String

    /// PostHog host, the EU proxy at `https://t.trackdown.nl` in every build.
    public var host: URL

    /// Which build the events come from, sent as the `environment` property.
    public var environment: AnalyticsEnvironment

    /// The app's marketing version, sent as the `app_version` property.
    public var appVersion: String

    public init(
        projectToken: String,
        host: URL,
        environment: AnalyticsEnvironment = .production,
        appVersion: String = ""
    ) {
        self.projectToken = projectToken
        self.host = host
        self.environment = environment
        self.appVersion = appVersion
    }

    /// Whether a project token is configured.
    public var isEnabled: Bool {
        !projectToken.isEmpty
    }
}

/// The build events come from. Matches the website's `environment` values, so one dashboard
/// filter covers both.
public enum AnalyticsEnvironment: String, Sendable, Equatable, CaseIterable {
    /// Debug builds.
    case development
    /// Release builds: TestFlight and the App Store.
    case production
}
