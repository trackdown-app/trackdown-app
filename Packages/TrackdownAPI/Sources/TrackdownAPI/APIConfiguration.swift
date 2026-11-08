import Foundation

/// Connection settings for the trackdown.nl `/api/v1` client.
public struct APIConfiguration: Sendable, Equatable {
    /// Base URL every request path is resolved against, for example `https://trackdown.nl/api/v1`.
    public var baseURL: URL

    /// Value of the `Trackdown-Client-Key` header sent with every call.
    public var clientKey: String

    public init(baseURL: URL, clientKey: String) {
        self.baseURL = baseURL
        self.clientKey = clientKey
    }
}
