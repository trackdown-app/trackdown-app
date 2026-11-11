#if os(iOS)
    import CryptoKit
    import DeviceCheck
    import Foundation

    /// Stores only the key ID; the private key remains managed by App Attest.
    actor DeviceAttester: RequestAttester {
        private let configuration: APIConfiguration
        private let storageKey: String
        private var keyID: String?

        init(configuration: APIConfiguration) {
            self.configuration = configuration
            storageKey = "trackdown.app-attest.\(configuration.baseURL.absoluteString)"
            keyID = UserDefaults.standard.string(forKey: storageKey)
        }

        func proof(for payload: Data) async throws -> AttestProof? {
            let service = DCAppAttestService.shared
            guard service.isSupported else { return nil }
            let key = try await registeredKey()
            do {
                let assertion = try await service.generateAssertion(
                    key, clientDataHash: Data(SHA256.hash(data: payload)))
                return AttestProof(keyID: key, assertion: assertion)
            } catch {
                // Invalid keys cannot be reused after restore/reinstall. Retry enrollment
                // on the next request; transient Apple failures keep the existing key.
                if (error as NSError).domain == DCError.errorDomain,
                    (error as NSError).code == DCError.invalidKey.rawValue
                {
                    keyID = nil
                    UserDefaults.standard.removeObject(forKey: storageKey)
                }
                throw error
            }
        }

        private func registeredKey() async throws -> String {
            if let keyID { return keyID }
            let service = DCAppAttestService.shared
            let key = try await service.generateKey()
            let challenge: Challenge = try await post("/api/v1/attest/challenge", body: ["keyId": key])
            let attestation = try await service.attestKey(
                key, clientDataHash: Data(SHA256.hash(data: Data(challenge.challenge.utf8))))
            let result: Registration = try await post(
                "/api/v1/attest",
                body: [
                    "keyId": key, "challenge": challenge.challenge, "attestation": attestation.base64EncodedString(),
                ])
            guard result.registered else { throw AttestationError.registrationFailed }
            keyID = key
            UserDefaults.standard.set(key, forKey: storageKey)
            return key
        }

        private func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
            var request = URLRequest(url: configuration.baseURL.appending(path: path))
            request.httpMethod = "POST"
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(configuration.clientKey, forHTTPHeaderField: "Trackdown-Client-Key")
            request.setValue(configuration.appVersion, forHTTPHeaderField: "Trackdown-App-Version")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw AttestationError.registrationFailed
            }
            return try JSONDecoder().decode(T.self, from: data)
        }

        func invalidate() {
            keyID = nil
            UserDefaults.standard.removeObject(forKey: storageKey)
        }

        private struct Challenge: Decodable { var challenge: String }
        private struct Registration: Decodable { var registered: Bool }
        private enum AttestationError: Error { case registrationFailed }
    }

#endif
