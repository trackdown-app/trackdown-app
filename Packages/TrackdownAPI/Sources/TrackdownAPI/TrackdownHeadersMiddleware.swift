import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Identifies the app to the API on every call.
///
/// Adds `Trackdown-Client-Key` and `Trackdown-App-Version`, which the server needs on every call
/// except the spec itself (`401 unknown_client` without them). Removes any `Origin` header,
/// because the server answers a request that carries one with `403 cross_origin`.
public struct TrackdownHeadersMiddleware: ClientMiddleware {
    public var clientKey: String
    public var appVersion: String

    public init(clientKey: String, appVersion: String) {
        self.clientKey = clientKey
        self.appVersion = appVersion
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.trackdownClientKey] = clientKey
        request.headerFields[.trackdownAppVersion] = appVersion
        request.headerFields[.origin] = nil
        return try await next(request, body, baseURL)
    }
}

extension HTTPField.Name {
    /// Header that names the app's client key.
    public static let trackdownClientKey = Self("Trackdown-Client-Key")!

    /// Header that names the app's version.
    public static let trackdownAppVersion = Self("Trackdown-App-Version")!
}
