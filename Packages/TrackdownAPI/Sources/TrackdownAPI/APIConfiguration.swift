import Foundation

/// Connection settings for the trackdown.nl `/api/v1` client.
public struct APIConfiguration: Sendable, Equatable {
    /// Origin every request path is resolved against, for example `https://trackdown.nl`.
    ///
    /// The spec has no `servers` entry and its paths already start with `/api/v1`, so this is the
    /// site's origin without a path.
    public var baseURL: URL

    /// Value of the `Trackdown-Client-Key` header sent with every call.
    public var clientKey: String

    /// Value of the `Trackdown-App-Version` header sent with every call: the app's
    /// `CFBundleShortVersionString`, such as `1.4.2`.
    public var appVersion: String

    public init(baseURL: URL, clientKey: String, appVersion: String) {
        self.baseURL = baseURL
        self.clientKey = clientKey
        self.appVersion = appVersion
    }
}
