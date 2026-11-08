# Analytics

The app sends usage data to PostHog the same privacy-first way as the website (`trackdown-website`'s `docs/analytics.md`), into the same project, so web and app share dashboards.

## Where the code lives

`posthog-ios` is a dependency of the `Analytics` package only. The rest of the app talks to the `AnalyticsClient` protocol and never imports PostHog. `AnalyticsConfiguration.makeClient()` returns:

- `PostHogAnalytics` when a project token is configured. It runs its own `PostHogSDK` instance, not `PostHogSDK.shared`.
- `DisabledAnalytics`, which sends nothing, when `POSTHOG_PROJECT_TOKEN` is empty.

`AppModel` creates the client once at launch and holds it as `analytics`. Event properties are `AnalyticsValue`s (string, int, bool or null), so no arbitrary object can end up in an event. The typed event list arrives with #28.

## Host and token

| Setting | Where | Value |
| --- | --- | --- |
| `POSTHOG_HOST` | `Config/Base.xcconfig` | `https://t.trackdown.nl`, the managed EU proxy |
| `POSTHOG_PROJECT_TOKEN` | `Config/Secrets.xcconfig` | The public ingestion token; empty turns analytics off |
| `POSTHOG_ENVIRONMENT` | `Config/Debug.xcconfig`, `Config/Release.xcconfig` | `development` in Debug, `production` in Release |

Debug builds send to the same project tagged `environment: development`, as the website's local builds do. Leave the token empty in `Secrets.xcconfig` to send nothing at all.

## Privacy settings

`PostHogAnalytics.sdkConfiguration(for:superProperties:)` sets up the SDK:

- `personProfiles = .never` and no default person properties. The app never calls `identify`, `alias` or `group`; the protocol does not offer them.
- No IDFA: the SDK does not read the advertising identifier and the app does not link AdSupport. No App Tracking Transparency prompt.
- Session replay, surveys, element autocapture and autocapture of element text are off.
- Automatic screen views are off; the app sends its own (#28).
- Feature flags are not preloaded and no `$feature_flag_called` events are sent.
- Crash autocapture stays off (the SDK default).
- Application lifecycle events (`Application Installed`, `Application Opened`, `Application Backgrounded`) stay on, the app's equivalent of the website's pageviews.
- `$ip` is set to `null` on every event, as on the website. The project setting that discards IP data still applies.

The anonymous-until-allowed mode (no persisted distinct id before the player says yes) and the consent prompt are #19. Until then every event goes out with `consent_analytics: null`.

## Super properties

A `beforeSend` hook adds these to every event, including the SDK's own lifecycle events. They are not registered with the SDK, so nothing about consent is persisted by PostHog.

| Property | Value |
| --- | --- |
| `environment` | `development` or `production` |
| `platform` | `ios` |
| `app_version` | `CFBundleShortVersionString` |
| `consent_analytics` | `null` before an answer, then `true` or `false` |
| `consent_marketing` | Always `false`, as on the website |
| `consent_version` | `AnalyticsConsent.textVersion`, currently `1`, matching the website's `CONSENT_TEXT_VERSION` |

`setConsent(_:)` changes `consent_analytics` for every later event.

## Tests

`Packages/Analytics/Tests` checks the super properties, the SDK configuration and the `beforeSend` properties. They send nothing to PostHog. Run them with `swift test --package-path Packages/Analytics`.
