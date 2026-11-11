# Privacy

What the app collects, what it declares to Apple, and the answers to give in App Store Connect. How analytics is wired is in [analytics.md](analytics.md). A change to what is collected, stored or sent changes this page, `Trackdown/PrivacyInfo.xcprivacy` and the App Store answers in the same change.

## What the player is asked

The app asks once, in a sheet over the playing screen. On first launch it follows How to play, so its toast lands on the playing screen.

- **Until the player allows:** the PostHog SDK is not set up. No event is sent, and no anonymous id or device id is written to disk.
- **Allow:** the SDK starts and keeps a random anonymous id for this install. Events carry `consent_analytics: true` and `consent_version`.
- **Don't allow**, or turning the Privacy toggle off later: the SDK is shut down and its directory, with the ids and any unsent events, is deleted. Nothing is sent, including the refusal itself.

The answer is stored with the consent text version, so the prompt never shows again unless `AnalyticsConsent.textVersion` is raised. After the answer a toast confirms it and links to Privacy settings, where the choice can be changed at any time.

This is stricter than the website, which counts cookieless pageviews before an answer and after a refusal. posthog-ios has no cookieless mode, and the prompt promises that the app shares usage data "with your OK", so the app sends nothing without it.

## No tracking

The app does not track in Apple's sense: no advertising, no data brokers, no linking with data from other apps or sites. It does not read the IDFA, does not link AdSupport or AppTrackingTransparency, and has no `NSUserTrackingUsageDescription`. There is no App Tracking Transparency prompt, and none is needed.

## Privacy manifest

`Trackdown/PrivacyInfo.xcprivacy` is copied into the app bundle (the `Trackdown` folder is a synchronized group). posthog-ios ships its own manifest, which Xcode merges into the privacy report (Product > Archive, then Generate Privacy Report).

| Key | Value | Why |
| --- | --- | --- |
| `NSPrivacyTracking` | `false` | See above |
| `NSPrivacyTrackingDomains` | Empty | No tracking domains |
| Collected: Product Interaction | Not linked, not tracking, purpose Analytics | Screen views, guesses, results, shares, app opened and backgrounded |
| Collected: Device ID | Not linked, not tracking, purposes Analytics and App Functionality | Optional PostHog anonymous id; App Attest installation key ID when enabled |
| Accessed API: User Defaults | `CA92.1` | The app's own settings: consent, chosen network, whether How to play was seen |

The app's own code uses no other required-reason API. posthog-ios declares its own (User Defaults `CA92.1`, system boot time `35F9.1`, file timestamp `C617.1`).

## App Store privacy answers

App Store Connect > App Privacy.

**Do you or your third-party partners collect data from this app?** Yes.

| Data type | Collected | Purpose | Linked to the user | Used for tracking |
| --- | --- | --- | --- | --- |
| Usage Data > Product Interaction | Yes | Analytics | No | No |
| Identifiers > Device ID | Yes | Analytics, App Functionality | No | No |
| Everything else (contact info, location, user content, purchases, diagnostics, ...) | No | | | |

Notes for filling it in:

- Analytics collection is optional and off until the player allows it. App Attest security records, when enabled, are required independently of analytics consent.
- The analytics Device ID is a random id PostHog generates per install. It is not the IDFA or IDFV, is deleted when the player turns usage data off, and no person profile is ever created from it. The separate App Attest key ID remains for API security.
- Events hold the network, puzzle number, guess counts and screen names. They never hold station names, the answer, search text or share text.
- The IP address reaches PostHog's EU proxy with each request, as with any request. `$ip` is set to `null` on every event and the project discards IP data, so no location is derived or stored.
- Game requests carry the client key and app version and are not used for analytics. With App Attest enabled, they also carry an installation key ID and a signed proof. The server stores its public key and replay counter in Upstash Redis for the registration's lifetime; challenges expire after five minutes. These security records are independent of analytics consent and never go to PostHog. Declare Device ID for App Functionality as well as optional Analytics before enabling the distribution build.
- Crash capture, session replay, surveys and feature flags are off, so no Diagnostics are collected.

**Privacy policy URL:** `https://trackdown.nl/privacy` (Dutch), `https://trackdown.nl/en/privacy` (English).
