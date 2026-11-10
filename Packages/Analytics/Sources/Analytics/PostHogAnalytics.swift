import Foundation
import PostHog
import Synchronization

/// Sends events to PostHog through the EU proxy, set up the privacy-first way the website is:
/// no person profiles, no `identify`, no IDFA, no session replay, no autocapture of text.
///
/// The SDK writes an anonymous id and a device id to disk as soon as it is set up, so it only runs
/// while the player allows usage data. Before an answer and after a refusal there is no SDK, no
/// stored identifier and no request to PostHog.
@MainActor
public final class PostHogAnalytics: AnalyticsClient {
    private let superProperties: SuperPropertiesStore
    private let storageDirectory: URL?
    private let startEngine: (SuperPropertiesStore) -> any AnalyticsEngine
    private var engine: (any AnalyticsEngine)?

    public convenience init(configuration: AnalyticsConfiguration, consent: AnalyticsConsent = .unanswered) {
        self.init(
            configuration: configuration,
            consent: consent,
            storageDirectory: Self.sdkStorageDirectory(projectToken: configuration.projectToken)
        ) { PostHogEngine(Self.sdkConfiguration(for: configuration, superProperties: $0)) }
    }

    /// - Parameters:
    ///   - storageDirectory: Where the SDK keeps its identifiers and queue, removed whenever usage data is not allowed.
    ///   - startEngine: Sets up the SDK. Called only once the player allows usage data.
    init(
        configuration: AnalyticsConfiguration,
        consent: AnalyticsConsent,
        storageDirectory: URL?,
        startEngine: @escaping (SuperPropertiesStore) -> any AnalyticsEngine
    ) {
        superProperties = SuperPropertiesStore(
            SuperProperties(
                environment: configuration.environment,
                appVersion: configuration.appVersion,
                consent: consent
            )
        )
        self.storageDirectory = storageDirectory
        self.startEngine = startEngine
        // Also removes what an earlier run left behind, such as after a consent text change.
        setConsent(consent)
    }

    /// Whether the SDK is set up, which it is only while usage data is allowed.
    var isRunning: Bool { engine != nil }

    public func capture(_ event: AnalyticsEvent) {
        engine?.capture(event.name, properties: event.properties.mapValues(\.sdkValue))
    }

    public func setConsent(_ consent: AnalyticsConsent) {
        superProperties.update { $0.consent = consent }
        if consent == .allowed {
            if engine == nil { engine = startEngine(superProperties) }
        } else {
            engine?.stop()
            engine = nil
            removeStoredIdentity()
        }
    }

    /// Deletes the SDK's anonymous id, device id and unsent events.
    private func removeStoredIdentity() {
        guard let storageDirectory else { return }
        try? FileManager.default.removeItem(at: storageDirectory)
    }

    /// The directory posthog-ios 3.x keeps its files in: `Application Support/<bundle id>/<project token>`.
    /// The SDK has no public call that removes its device id, so the directory is removed instead.
    nonisolated static func sdkStorageDirectory(
        projectToken: String,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        applicationSupport: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
    ) -> URL? {
        guard let bundleIdentifier, let applicationSupport, !projectToken.isEmpty else { return nil }
        return
            applicationSupport
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent(projectToken, isDirectory: true)
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

        // The app sends its own screen events. Swizzled UIKit screen names say nothing in
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

/// The running SDK. One exists only while the player allows usage data.
@MainActor
protocol AnalyticsEngine: AnyObject {
    func capture(_ name: String, properties: [String: Any])

    /// Forgets the identity and shuts the SDK down.
    func stop()
}

private final class PostHogEngine: AnalyticsEngine {
    private let sdk: PostHogSDK

    init(_ config: PostHogConfig) {
        // Our own instance rather than `PostHogSDK.shared`, so nothing else can reach it.
        sdk = PostHogSDK.with(config)
        // An opt-out the SDK stored on an earlier run must not override the app's versioned choice.
        sdk.optIn()
    }

    func capture(_ name: String, properties: [String: Any]) {
        sdk.capture(name, properties: properties)
    }

    func stop() {
        sdk.reset()
        sdk.close()
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
