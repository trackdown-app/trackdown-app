import Foundation
import PostHog
import Testing

@testable import Analytics

@MainActor
struct PostHogAnalyticsTests {
    private func makeConfig(consent: AnalyticsConsent = .unanswered) throws -> (PostHogConfig, SuperPropertiesStore) {
        let host = try #require(URL(string: "https://t.trackdown.nl"))
        let configuration = AnalyticsConfiguration(
            projectToken: "phc_test",
            host: host,
            environment: .development,
            appVersion: "0.1.0"
        )
        let store = SuperPropertiesStore(
            SuperProperties(environment: .development, appVersion: "0.1.0", consent: consent)
        )
        return (PostHogAnalytics.sdkConfiguration(for: configuration, superProperties: store), store)
    }

    @Test("Sends to the EU proxy with the configured token")
    func hostAndToken() throws {
        let (config, _) = try makeConfig()

        #expect(config.host.absoluteString == "https://t.trackdown.nl")
        #expect(config.projectToken == "phc_test")
    }

    @Test("Never creates person profiles")
    func noPersonProfiles() throws {
        let (config, _) = try makeConfig()

        #expect(config.personProfiles == .never)
        #expect(config.setDefaultPersonProperties == false)
    }

    @Test("Captures no screens, flags or surveys on its own")
    func noAutomaticCapture() throws {
        let (config, _) = try makeConfig()

        #expect(config.captureScreenViews == false)
        #expect(config.preloadFeatureFlags == false)
        #expect(config.sendFeatureFlagEvent == false)
        #expect(config.errorTrackingConfig.autoCapture == false)
    }

    @Test("Adds super properties and drops the IP address")
    func beforeSendProperties() {
        let superProperties = SuperProperties(environment: .production, appVersion: "2.0", consent: .declined)

        let result = PostHogAnalytics.addingSuperProperties(
            superProperties,
            to: ["network": "nl", "$ip": "192.0.2.1"]
        )

        #expect(result["network"] as? String == "nl")
        #expect(result["environment"] as? String == "production")
        #expect(result["platform"] as? String == "ios")
        #expect(result["app_version"] as? String == "2.0")
        #expect(result["consent_analytics"] as? Bool == false)
        #expect(result["consent_version"] as? Int == AnalyticsConsent.textVersion)
        #expect(result["$ip"] is NSNull)
    }

    @Test("Sends consent_analytics as null before an answer")
    func unansweredConsentIsNull() {
        let superProperties = SuperProperties(environment: .production, appVersion: "2.0", consent: .unanswered)

        let result = PostHogAnalytics.addingSuperProperties(superProperties, to: [:])

        #expect(result["consent_analytics"] is NSNull)
    }

    @Test("Uses the new consent on later events")
    func consentUpdates() throws {
        let (_, store) = try makeConfig()

        store.update { $0.consent = .allowed }

        #expect(store.current.consent == .allowed)
    }

    @Test(
        "Runs no SDK and keeps no identifier until the player allows",
        arguments: [AnalyticsConsent.unanswered, .declined])
    func anonymousUntilAllowed(consent: AnalyticsConsent) throws {
        let harness = try Harness(consent: consent, leftover: true)

        harness.analytics.capture(.networkNotifyRequested(.be))

        #expect(!harness.analytics.isRunning)
        #expect(harness.engines.isEmpty)
        #expect(!harness.hasStoredIdentity)
    }

    @Test("Allowing starts the SDK once and sends later events through it")
    func allowStarts() throws {
        let harness = try Harness(consent: .unanswered)

        harness.analytics.setConsent(.allowed)
        harness.analytics.setConsent(.allowed)
        harness.analytics.capture(.networkNotifyRequested(.be))

        #expect(harness.engines.count == 1)
        #expect(harness.engines.first?.events == ["network_notify_requested"])
        #expect(harness.consentSeenAtStart == [.allowed])
    }

    @Test("A saved Allow starts the SDK at launch and keeps its identifier")
    func allowedAtLaunch() throws {
        let harness = try Harness(consent: .allowed, leftover: true)

        #expect(harness.analytics.isRunning)
        #expect(harness.hasStoredIdentity)
    }

    @Test("Withdrawing stops the SDK and removes its identifier")
    func withdraw() throws {
        let harness = try Harness(consent: .allowed, leftover: true)

        harness.analytics.setConsent(.declined)
        harness.analytics.capture(.networkNotifyRequested(.be))

        #expect(!harness.analytics.isRunning)
        #expect(harness.engines.first?.isStopped == true)
        #expect(harness.engines.first?.events.isEmpty == true)
        #expect(!harness.hasStoredIdentity)
    }

    @Test("The SDK's files live under Application Support, by bundle id and project token")
    func storageDirectory() throws {
        let support = try #require(URL(string: "file:///support/"))

        let directory = PostHogAnalytics.sdkStorageDirectory(
            projectToken: "phc_test", bundleIdentifier: "nl.trackdown.Trackdown", applicationSupport: support)

        #expect(directory?.path == "/support/nl.trackdown.Trackdown/phc_test")
        #expect(
            PostHogAnalytics.sdkStorageDirectory(
                projectToken: "phc_test", bundleIdentifier: nil, applicationSupport: support) == nil)
    }

    @Test("Starts opted out unless the player allowed usage data", arguments: AnalyticsConsent.allCases)
    func startupConsent(consent: AnalyticsConsent) throws {
        let (config, _) = try makeConfig(consent: consent)
        #expect(config.optOut == (consent != .allowed))
    }
}

/// A `PostHogAnalytics` with a fake SDK and a temporary storage directory.
@MainActor
private final class Harness {
    private(set) var engines: [FakeEngine] = []
    private(set) var consentSeenAtStart: [AnalyticsConsent] = []
    private(set) var analytics: PostHogAnalytics!
    private let directory: URL

    /// - Parameter leftover: Whether an earlier run left an anonymous id on disk.
    init(consent: AnalyticsConsent, leftover: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PostHogAnalyticsTests.\(UUID().uuidString)", isDirectory: true)
        if leftover {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("id".utf8).write(to: directory.appendingPathComponent("posthog.anonymousId"))
        }
        let host = try #require(URL(string: "https://t.trackdown.nl"))
        analytics = PostHogAnalytics(
            configuration: AnalyticsConfiguration(projectToken: "phc_test", host: host),
            consent: consent,
            storageDirectory: directory
        ) { [unowned self] superProperties in
            consentSeenAtStart.append(superProperties.current.consent)
            let engine = FakeEngine()
            engines.append(engine)
            return engine
        }
    }

    var hasStoredIdentity: Bool {
        FileManager.default.fileExists(atPath: directory.path)
    }
}

@MainActor
private final class FakeEngine: AnalyticsEngine {
    private(set) var events: [String] = []
    private(set) var isStopped = false

    func capture(_ name: String, properties: [String: Any]) {
        events.append(name)
    }

    func stop() {
        isStopped = true
    }
}
