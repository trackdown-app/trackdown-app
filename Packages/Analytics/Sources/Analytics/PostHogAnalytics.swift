import Foundation
import PostHog
import Synchronization

/// Sends events to PostHog through the EU proxy, set up the privacy-first way the website is:
/// no person profiles, no `identify`, no IDFA, no session replay, no autocapture of text.
@MainActor
public final class PostHogAnalytics: AnalyticsClient {
    private let sdk: PostHogSDK
    private let superProperties: SuperPropertiesStore

    public init(configuration: AnalyticsConfiguration, consent: AnalyticsConsent = .unanswered) {
        let store = SuperPropertiesStore(
            SuperProperties(
                environment: configuration.environment,
                appVersion: configuration.appVersion,
                consent: consent
            )
        )
        superProperties = store
        // Our own instance rather than `PostHogSDK.shared`, so nothing else can reach it.
        sdk = PostHogSDK.with(Self.sdkConfiguration(for: configuration, superProperties: store))
        // A PostHog choice from an earlier run must not override the app's versioned choice.
        setConsent(consent)
    }

    public func capture(_ event: String, properties: [String: AnalyticsValue]) {
        sdk.capture(event, properties: properties.mapValues(\.sdkValue))
    }

    public func setConsent(_ consent: AnalyticsConsent) {
        superProperties.update { $0.consent = consent }
        if consent == .allowed {
            sdk.optIn()
        } else {
            sdk.optOut()
        }
    }

    static func sdkConfiguration(
        for configuration: AnalyticsConfiguration,
        superProperties: SuperPropertiesStore
    ) -> PostHogConfig {
        let config = PostHogConfig(projectToken: configuration.projectToken, host: configuration.host.absoluteString)

        // The app's versioned choice is the only source of truth, including before setup emits events.
        config.optOut = superProperties.current.consent != .allowed

        // Anonymous only: events never create or update a person.
        config.personProfiles = .never
        config.setDefaultPersonProperties = false

        // The app sends its own screen events (#28). Swizzled UIKit screen names say nothing in
        // a SwiftUI app.
        config.captureScreenViews = false

        // No feature flags or surveys, so no requests for them.
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false

        #if os(iOS)
            config.sessionReplay = false
            config.surveys = false
            config.captureElementInteractions = false
            config.captureSwiftUIElementInteractions = false
            config.captureAutocaptureElementText = false
        #endif

        config.setBeforeSend { event in
            let current = superProperties.current
            // Also blocks setup events if the SDK restores an older opt-in before we reconcile it.
            guard current.consent == .allowed else { return nil }
            event.properties = Self.addingSuperProperties(current, to: event.properties)
            return event
        }
        return config
    }

    /// `properties` with the super properties added and the IP address removed, as the website
    /// does in `before_send`.
    nonisolated static func addingSuperProperties(
        _ superProperties: SuperProperties,
        to properties: [String: Any]
    ) -> [String: Any] {
        var result = properties
        for (key, value) in superProperties.values {
            result[key] = value.sdkValue
        }
        result["$ip"] = NSNull()
        return result
    }
}

/// The current super properties, read by the SDK's `beforeSend` on its own queue.
final class SuperPropertiesStore: Sendable {
    private let state: Mutex<SuperProperties>

    init(_ initial: SuperProperties) {
        state = Mutex(initial)
    }

    var current: SuperProperties {
        state.withLock { $0 }
    }

    func update(_ change: (inout SuperProperties) -> Void) {
        state.withLock { change(&$0) }
    }
}
