import Foundation
import HTTPTypes
import OpenAPIRuntime
import Synchronization
import TrackdownAPI

/// A canned HTTP answer.
struct MockResponse: Sendable {
    var status: Int
    var headers: HTTPFields = [:]
    var body: String?

    static func json(_ body: String, status: Int = 200, headers: HTTPFields = [:]) -> MockResponse {
        var headers = headers
        headers[.contentType] = "application/json"
        return MockResponse(status: status, headers: headers, body: body)
    }

    /// An `ApiError` body with `code`.
    static func apiError(_ code: String, status: Int, headers: HTTPFields = [:]) -> MockResponse {
        json(#"{"error":{"code":"\#(code)","message":"test"}}"#, status: status, headers: headers)
    }
}

/// Answers every call with the next canned response (or throws the next error) and records what was sent.
actor MockTransport: ClientTransport {
    struct Sent: Sendable {
        var request: HTTPRequest
        var body: String?
        var operationID: String
    }

    enum Answer: Sendable {
        case response(MockResponse)
        case failure(any Error)
    }

    private var answers: [Answer]
    private(set) var sent: [Sent] = []

    init(_ answers: [Answer]) {
        self.answers = answers
    }

    init(_ responses: MockResponse...) {
        self.answers = responses.map(Answer.response)
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let bodyString: String? =
            if let body { try await String(collecting: body, upTo: 1 << 20) } else { nil }
        sent.append(Sent(request: request, body: bodyString, operationID: operationID))

        guard !answers.isEmpty else { throw MockTransportError.noAnswerLeft(operationID) }
        switch answers.removeFirst() {
        case .failure(let error):
            throw error
        case .response(let response):
            return (
                HTTPResponse(status: .init(code: response.status), headerFields: response.headers),
                response.body.map { HTTPBody($0) }
            )
        }
    }
}

enum MockTransportError: Error {
    case noAnswerLeft(String)
}

/// A clock tests move by hand.
final class TestClock: Sendable {
    private let current: Mutex<Date>

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        current = Mutex(start)
    }

    var now: Date { current.withLock { $0 } }

    func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

extension TrackdownPuzzleService {
    /// A service on `transport` with the app's client, a hand-moved clock and the given station cache.
    static func test(
        _ transport: MockTransport,
        clock: TestClock = TestClock(),
        stationCache: StationCache? = nil
    ) -> TrackdownPuzzleService {
        let configuration = APIConfiguration(
            baseURL: URL(string: "https://trackdown.nl")!,
            clientKey: "test-key",
            appVersion: "1.0.0"
        )
        return TrackdownPuzzleService(
            client: Client(apiConfiguration: configuration, transport: transport),
            stationCache: stationCache,
            now: { clock.now }
        )
    }
}

/// Parses a JSON request body so tests compare values, not key order.
func jsonObject(_ string: String?) throws -> NSDictionary? {
    guard let data = string?.data(using: .utf8) else { return nil }
    return try JSONSerialization.jsonObject(with: data) as? NSDictionary
}
