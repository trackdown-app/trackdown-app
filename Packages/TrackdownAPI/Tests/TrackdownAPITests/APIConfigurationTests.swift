import Foundation
import Testing
import TrackdownAPI

struct APIConfigurationTests {
    @Test func storesBaseURLAndClientKey() throws {
        let url = try #require(URL(string: "https://trackdown.nl/api/v1"))
        let configuration = APIConfiguration(baseURL: url, clientKey: "key")

        #expect(configuration.baseURL == url)
        #expect(configuration.clientKey == "key")
    }
}
