import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
import TrackdownAPI

struct TrackdownHeadersMiddlewareTests {
    private let middleware = TrackdownHeadersMiddleware(clientKey: "test-key", appVersion: "1.4.2")

    @Test("Adds the client key and app version headers")
    func addsHeaders() async throws {
        let sent = try await send(HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/api/v1/meta"))

        #expect(sent.headerFields[.trackdownClientKey] == "test-key")
        #expect(sent.headerFields[.trackdownAppVersion] == "1.4.2")
    }

    @Test("Removes an Origin header, which the server rejects with 403 cross_origin")
    func removesOrigin() async throws {
        var request = HTTPRequest(method: .post, scheme: nil, authority: nil, path: "/api/v1/nl/puzzles/1/guesses")
        request.headerFields[.origin] = "https://trackdown.nl"

        let sent = try await send(request)

        #expect(sent.headerFields[.origin] == nil)
    }

    @Test("Replaces stale identification headers instead of sending them twice")
    func replacesExistingHeaders() async throws {
        var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/api/v1/meta")
        request.headerFields[.trackdownClientKey] = "old-key"
        request.headerFields.append(HTTPField(name: .trackdownAppVersion, value: "0.0.1"))
        request.headerFields.append(HTTPField(name: .trackdownAppVersion, value: "0.0.2"))

        let sent = try await send(request)

        #expect(sent.headerFields[values: .trackdownClientKey] == ["test-key"])
        #expect(sent.headerFields[values: .trackdownAppVersion] == ["1.4.2"])
    }

    @Test("Keeps the request's other headers")
    func keepsOtherHeaders() async throws {
        var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/api/v1/meta")
        request.headerFields[.accept] = "application/json"

        let sent = try await send(request)

        #expect(sent.headerFields[.accept] == "application/json")
    }

    @Test("A client built from APIConfiguration sends the headers to the spec's paths on the origin")
    func clientUsesMiddlewareAndOrigin() async throws {
        let transport = RecordingTransport()
        let configuration = APIConfiguration(
            baseURL: try #require(URL(string: "https://trackdown.nl")),
            clientKey: "test-key",
            appVersion: "1.4.2"
        )
        let client = Client(apiConfiguration: configuration, transport: transport)

        _ = try await client.getMeta(.init(query: .init(network: .nl)))

        let recorded = try #require(await transport.requests.first)
        #expect(recorded.baseURL.absoluteString == "https://trackdown.nl")
        #expect(recorded.request.path == "/api/v1/meta?network=nl")
        #expect(recorded.request.headerFields[.trackdownClientKey] == "test-key")
        #expect(recorded.request.headerFields[.trackdownAppVersion] == "1.4.2")
        #expect(recorded.request.headerFields[.origin] == nil)
    }

    private func send(_ request: HTTPRequest) async throws -> HTTPRequest {
        let transport = RecordingTransport()
        let baseURL = try #require(URL(string: "https://trackdown.nl"))
        _ = try await middleware.intercept(request, body: nil, baseURL: baseURL, operationID: "test") {
            request, body, baseURL in
            try await transport.send(request, body: body, baseURL: baseURL, operationID: "test")
        }
        return try #require(await transport.requests.first).request
    }
}

/// Records what the client would send and answers every call with an empty `204`.
private actor RecordingTransport: ClientTransport {
    struct Recorded {
        var request: HTTPRequest
        var baseURL: URL
    }

    private(set) var requests: [Recorded] = []

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        requests.append(Recorded(request: request, baseURL: baseURL))
        return (HTTPResponse(status: .noContent), nil)
    }
}
