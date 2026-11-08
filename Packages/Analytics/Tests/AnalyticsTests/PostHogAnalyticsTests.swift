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

    @Test("Starts opted out unless the player allowed usage data", arguments: AnalyticsConsent.allCases)
    func startupConsent(consent: AnalyticsConsent) throws {
        let (config, _) = try makeConfig(consent: consent)
        #expect(config.optOut == (consent != .allowed))
    }
}
