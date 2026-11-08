import Foundation

/// Settings for the PostHog-backed analytics client.
public struct AnalyticsConfiguration: Sendable, Equatable {
    /// PostHog project token. Empty means analytics is off.
    public var projectToken: String

    /// PostHog host, the EU proxy at `https://t.trackdown.nl` in every build.
    public var host: URL

    public init(projectToken: String, host: URL) {
        self.projectToken = projectToken
        self.host = host
    }

    /// Whether a project token is configured.
    public var isEnabled: Bool {
        !projectToken.isEmpty
    }
}
