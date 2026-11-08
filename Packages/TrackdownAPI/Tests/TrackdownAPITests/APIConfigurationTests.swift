import Foundation
import Testing
import TrackdownAPI

struct APIConfigurationTests {
    @Test func storesBaseURLClientKeyAndAppVersion() throws {
        let url = try #require(URL(string: "https://trackdown.nl"))
        let configuration = APIConfiguration(baseURL: url, clientKey: "key", appVersion: "1.4.2")

        #expect(configuration.baseURL == url)
        #expect(configuration.clientKey == "key")
        #expect(configuration.appVersion == "1.4.2")
    }
}
