import Foundation
import Testing

@testable import Analytics

@MainActor
struct AnalyticsSettingsTests {
    let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "AnalyticsSettingsTests.\(UUID().uuidString)"))
    }

    @Test("An unanswered choice starts off without storing an answer")
    func unanswered() {
        let settings = makeSettings()
        #expect(settings.consent == .unanswered)
        #expect(!settings.sharesUsageData)
        #expect(defaults.object(forKey: AnalyticsSettings.key) == nil)
    }

    @Test("Each toggle immediately updates the client and survives a relaunch")
    func toggleAndRestore() {
        let client = ConsentClient()
        let settings = makeSettings(client: client)
        settings.sharesUsageData = true
        #expect(client.choices == [.allowed])
        #expect(makeSettings().consent == .allowed)
        settings.sharesUsageData = false
        #expect(client.choices == [.allowed, .declined])
        #expect(makeSettings().consent == .declined)
    }

    @Test("The client is constructed with the restored choice", arguments: [true, false])
    func startup(allowed: Bool) {
        defaults.set(["version": AnalyticsConsent.textVersion, "allowed": allowed], forKey: AnalyticsSettings.key)
        var initial: AnalyticsConsent?
        _ = AnalyticsSettings(defaults: defaults) {
            initial = $0
            return ConsentClient()
        }
        #expect(initial == (allowed ? .allowed : .declined))
    }

    @Test("An outdated or incomplete answer requires a new choice", arguments: [0, 1, 2])
    func invalidChoice(example: Int) {
        let examples: [[String: Any]] = [
            ["version": AnalyticsConsent.textVersion - 1, "allowed": true],
            ["version": AnalyticsConsent.textVersion],
            ["allowed": true],
        ]
        let saved = examples[example]
        defaults.set(saved, forKey: AnalyticsSettings.key)
        #expect(makeSettings().consent == .unanswered)
    }

    @Test("Resetting consent removes the saved answer and updates the client")
    func reset() {
        let client = ConsentClient()
        let settings = makeSettings(client: client)
        settings.sharesUsageData = true
        settings.setConsent(.unanswered)
        #expect(client.choices == [.allowed, .unanswered])
        #expect(makeSettings().consent == .unanswered)
        #expect(defaults.object(forKey: AnalyticsSettings.key) == nil)
    }

    private func makeSettings(client: ConsentClient = ConsentClient()) -> AnalyticsSettings {
        AnalyticsSettings(defaults: defaults) { _ in client }
    }
}

@MainActor
private final class ConsentClient: AnalyticsClient {
    var choices: [AnalyticsConsent] = []

    func capture(_ event: String, properties: [String: AnalyticsValue]) {}

    func setConsent(_ consent: AnalyticsConsent) {
        choices.append(consent)
    }
}
