import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

extension Client {
    /// Creates a client for the Trackdown API that sends the app's headers on every call.
    ///
    /// - Parameters:
    ///   - apiConfiguration: Origin, client key and app version, read from the xcconfig files.
    ///   - transport: Performs the HTTP calls. Defaults to `URLSession.shared`.
    public init(
        apiConfiguration: APIConfiguration,
        transport: any ClientTransport = URLSessionTransport()
    ) {
        self.init(
            serverURL: apiConfiguration.baseURL,
            transport: transport,
            middlewares: [
                TrackdownHeadersMiddleware(
                    clientKey: apiConfiguration.clientKey,
                    appVersion: apiConfiguration.appVersion
                )
            ]
        )
    }
}
