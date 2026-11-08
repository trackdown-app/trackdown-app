import Analytics
import Foundation
import Testing

struct AnalyticsConfigurationTests {
    @Test(arguments: [("", false), ("phc_token", true)])
    func isEnabledOnlyWithToken(token: String, expected: Bool) throws {
        let host = try #require(URL(string: "https://t.trackdown.nl"))
        let configuration = AnalyticsConfiguration(projectToken: token, host: host)

        #expect(configuration.isEnabled == expected)
    }
}
