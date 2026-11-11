import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import TrackdownAPI

struct AppAttestMiddlewareTests {
    @Test("Payload matches backend contract exactly, including empty body hash")
    func payload() {
        #expect(
            AppAttestMiddleware.payload(
                method: "GET", path: "/api/v1/meta?network=nl", body: Data(), timestamp: "1234567890")
                == "trackdown-app-attest-v1\n1234567890\nGET\n/api/v1/meta?network=nl\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    @Test("Signs transmitted bytes and forwards replayable body")
    func signs() async throws {
        let attester = FakeAttester()
        let middleware = AppAttestMiddleware(attester: attester)
        let bytes = Data("{\"guess\":\"ASD\"}".utf8)
        _ = try await middleware.intercept(
            HTTPRequest(
                method: .post, scheme: "https", authority: "trackdown.nl", path: "/api/v1/nl/puzzles/2/guesses"),
            body: HTTPBody(bytes), baseURL: URL(string: "https://trackdown.nl")!, operationID: "guess"
        ) { request, body, _ in
            #expect(request.headerFields[HTTPField.Name("Trackdown-Attest-Key-Id")!] == "key")
            #expect(
                request.headerFields[HTTPField.Name("Trackdown-Attest-Assertion")!]
                    == Data("proof".utf8).base64EncodedString())
            let body = try #require(body)
            #expect(try await Data(collecting: body, upTo: 65536) == bytes)
            return (HTTPResponse(status: .ok), nil)
        }
        #expect(await attester.payloads.count == 1)
    }

    @Test("Unsupported devices keep existing headers without proof")
    func unsupported() async throws {
        let middleware = AppAttestMiddleware(attester: FakeAttester(supported: false))
        _ = try await middleware.intercept(
            HTTPRequest(method: .get, scheme: "https", authority: "trackdown.nl", path: "/api/v1/meta"),
            body: nil, baseURL: URL(string: "https://trackdown.nl")!, operationID: "meta"
        ) { request, body, _ in
            #expect(request.headerFields[HTTPField.Name("Trackdown-Attest-Assertion")!] == nil)
            #expect(body == nil)
            return (HTTPResponse(status: .ok), nil)
        }
    }

    @Test("Rejected registrations are cleared for enrollment on next request")
    func rejected() async throws {
        let attester = FakeAttester()
        let middleware = AppAttestMiddleware(attester: attester)
        _ = try await middleware.intercept(
            HTTPRequest(method: .get, scheme: "https", authority: "trackdown.nl", path: "/api/v1/meta"),
            body: nil, baseURL: URL(string: "https://trackdown.nl")!, operationID: "meta"
        ) { _, _, _ in (HTTPResponse(status: .unauthorized), nil) }
        #expect(await attester.invalidated)
    }
}

private actor FakeAttester: RequestAttester {
    let supported: Bool
    var payloads: [Data] = []
    var invalidated = false

    init(supported: Bool = true) { self.supported = supported }
    func proof(for payload: Data) -> AttestProof? {
        payloads.append(payload)
        return supported ? AttestProof(keyID: "key", assertion: Data("proof".utf8)) : nil
    }
    func invalidate() { invalidated = true }
}
