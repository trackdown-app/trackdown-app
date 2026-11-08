import Analytics
import Testing

struct SuperPropertiesTests {
    @Test("Adds environment, platform, version and consent to every event")
    func values() {
        let properties = SuperProperties(environment: .production, appVersion: "1.2.0", consent: .allowed)

        #expect(
            properties.values == [
                "environment": "production",
                "platform": "ios",
                "app_version": "1.2.0",
                "consent_analytics": true,
                "consent_marketing": false,
                "consent_version": 1,
            ]
        )
    }

    @Test(
        "Sends consent_analytics as null, true or false",
        arguments: [
            (AnalyticsConsent.unanswered, AnalyticsValue.null),
            (.allowed, .bool(true)),
            (.declined, .bool(false)),
        ]
    )
    func consent(consent: AnalyticsConsent, expected: AnalyticsValue) {
        let properties = SuperProperties(environment: .development, appVersion: "1.0", consent: consent)

        #expect(properties.values["consent_analytics"] == expected)
    }

    @Test("Uses the website's environment names", arguments: AnalyticsEnvironment.allCases)
    func environment(environment: AnalyticsEnvironment) {
        let properties = SuperProperties(environment: environment, appVersion: "1.0", consent: .unanswered)

        #expect(properties.values["environment"] == .string(environment.rawValue))
        #expect(["development", "production"].contains(environment.rawValue))
    }
}
