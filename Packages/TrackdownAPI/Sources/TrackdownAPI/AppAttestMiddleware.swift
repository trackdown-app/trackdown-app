import CryptoKit
import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Signs the exact request bytes. Calls stay ordered until their responses arrive,
/// so the server never sees App Attest counters out of order.
actor AppAttestMiddleware: ClientMiddleware {
    let attester: any RequestAttester
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(attester: any RequestAttester) { self.attester = attester }

    func intercept(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if busy { await withCheckedContinuation { waiting.append($0) } }
        busy = true
        defer {
            if waiting.isEmpty { busy = false } else { waiting.removeFirst().resume() }
        }
        try Task.checkCancellation()
        let bytes: Data
        if let body { bytes = try await Data(collecting: body, upTo: 65536) } else { bytes = Data() }
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let payload = Self.payload(
            method: request.method.rawValue, path: request.path ?? "/", body: bytes, timestamp: timestamp)
        var signed = request
        if let proof = try await attester.proof(for: Data(payload.utf8)) {
            signed.headerFields[Self.keyHeader] = proof.keyID
            signed.headerFields[Self.assertionHeader] = proof.assertion.base64EncodedString()
            signed.headerFields[Self.timestampHeader] = timestamp
        }
        let response = try await next(signed, body == nil ? nil : HTTPBody(bytes), baseURL)
        if response.0.status == .unauthorized { await attester.invalidate() }
        return response
    }

    static func payload(method: String, path: String, body: Data, timestamp: String) -> String {
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        return ["trackdown-app-attest-v1", timestamp, method, path, hash].joined(separator: "\n")
    }

    private static let keyHeader = HTTPField.Name("Trackdown-Attest-Key-Id")!
    private static let assertionHeader = HTTPField.Name("Trackdown-Attest-Assertion")!
    private static let timestampHeader = HTTPField.Name("Trackdown-Attest-Timestamp")!
}

struct AttestProof: Sendable {
    var keyID: String
    var assertion: Data
}

protocol RequestAttester: Sendable {
    /// `nil` only when the platform does not support App Attest.
    func proof(for payload: Data) async throws -> AttestProof?
    func invalidate() async
}
