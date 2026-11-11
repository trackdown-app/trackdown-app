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
        var middlewares: [any ClientMiddleware] = [
            TrackdownHeadersMiddleware(clientKey: apiConfiguration.clientKey, appVersion: apiConfiguration.appVersion)
        ]
        #if os(iOS)
            if apiConfiguration.appAttestEnabled {
                middlewares.append(AppAttestMiddleware(attester: DeviceAttester(configuration: apiConfiguration)))
            }
        #endif
        self.init(
            serverURL: apiConfiguration.baseURL,
            configuration: Configuration(dateTranscoder: LenientISO8601DateTranscoder()),
            transport: transport,
            middlewares: middlewares
        )
    }
}

/// Reads `date-time` values with or without fractional seconds.
///
/// The server writes them with JavaScript's `toISOString()`, which always adds milliseconds
/// (`2026-11-08T23:00:00.000Z`). The runtime's default transcoder only accepts whole seconds, so every response with a
/// date failed to decode.
struct LenientISO8601DateTranscoder: DateTranscoder {
    private static let whole = Date.ISO8601FormatStyle()
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    func encode(_ date: Date) throws -> String {
        date.formatted(Self.whole)
    }

    func decode(_ string: String) throws -> Date {
        if let date = try? Self.fractional.parse(string) { return date }
        return try Self.whole.parse(string)
    }
}
