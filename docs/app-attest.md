# App Attest

The API client can enroll an App Attest key and sign every request. Backend
contract and rollout controls live in trackdown-website `docs/api.md#app-attest`.
The backend was added in [website PR #98](https://github.com/trackdown-app/trackdown-website/pull/98).
App Attest is enabled by default now that the backend change has merged.

1. Enable App Attest for `nl.trackdown.Trackdown` in the Apple Developer account
   and refresh signing profiles. Debug and Release both use production
   attestations because both call the Production API by default (including TestFlight).
2. Configure the backend's Team ID, bundle ID and Upstash Redis credentials. Deploy
   with `TRACKDOWN_ATTEST_MODE=observe`.
3. Use a client key reserved for attesting distribution builds.
   `TRACKDOWN_APP_ATTEST_ENABLED` defaults to `YES`. When overriding the API URL
   to a local/Preview backend without App Attest configuration, set it to `NO` in
   `Secrets.xcconfig`. To test development attestations against a configured
   non-Production backend, override `TRACKDOWN_APP_ATTEST_ENVIRONMENT=development`
   and enable that backend's development opt-in. Production rejects development
   attestations even for Debug builds.
4. Verify enrollment and signed GET/POST calls on a real device, relaunch, offline
   behavior, and recovery after a server registration is removed. Confirm counters
   increase and server replay checks reject captured requests.
5. After validating the distribution build, enforce its client key on the backend.
   Simulator/unsupported devices send the existing client headers only and need a
   separate accepted key outside the backend's enforced list. No client-side flag
   can bypass backend enforcement. Never ship that fallback key in distribution.

Enrollment hashes the UTF-8 challenge and sends Apple's attestation to the server.
The key ID is kept in User Defaults, scoped to the API origin; private keys stay
under App Attest control. Enrollment uses a separate URLSession request to avoid
recursively signing itself. A failed/lost enrollment starts with a new key on the
next call. Transient Apple failures throw rather than silently downgrade.

The middleware buffers at most 64 KiB, signs the exact method, encoded target,
body hash and timestamp, and serializes complete requests per client so counters
arrive in order. A 401 clears the registration for enrollment on the next request;
it does not automatically repeat a game operation. An invalid local key is cleared
too. Cancellation and failures release the serialized request queue.

Host tests cover the wire payload, body preservation, unsupported fallback and
401 recovery. DeviceCheck calls require a signed real-device build; simulator
builds cannot verify Apple's attestation service.
