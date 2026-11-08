# Analytics

The app sends usage data to PostHog the same privacy-first way as the website (`trackdown-website`'s `docs/analytics.md`), into the same project, so web and app share dashboards.

## Where the code lives

`posthog-ios` is a dependency of the `Analytics` package only. The rest of the app talks to the `AnalyticsClient` protocol and never imports PostHog. `AnalyticsConfiguration.makeClient()` returns:

- `PostHogAnalytics` when a project token is configured. It runs its own `PostHogSDK` instance, not `PostHogSDK.shared`.
- `DisabledAnalytics`, which sends nothing, when `POSTHOG_PROJECT_TOKEN` is empty.

`AppModel` creates the client once at launch and holds it as `analytics`, passing the same client to gameplay and results models. `AnalyticsClient.capture(_:)` accepts only `AnalyticsEvent`, a Swift enum whose cases define every allowed property. No call site can supply an arbitrary event name or property dictionary.

## Explicit events

Puzzle events match the website's `src/lib/analytics/events.ts`. Every one carries `network`, `puzzle_number` and `archive`; none carries station names or codes, trips, search text or share text.

| Event | Additional properties | When |
| --- | --- | --- |
| `puzzle_started` | None | The first accepted guess of a new game |
| `guess_made` | `guess_number`, starting at 1 | Each accepted guess |
| `puzzle_solved` / `puzzle_missed` | `guesses_used` | An accepted guess finishes the game |
| `archive_puzzle_played` | None | The first accepted guess from the Archive, including a resumed daily game |
| `result_shared` | `method`: `shared` or `copied` | The system share sheet completes successfully, including Copy |

Loading, replaying stored guesses, failed or refused guesses, and cancelled or failed shares send no puzzle events. Once an accepted archive guess makes a daily game an archive game, that flag stays stored across launches and later events keep `archive: true`. Reopening an archive game does not emit `archive_puzzle_played` again.

App-only events:

| Event | Properties | When |
| --- | --- | --- |
| `$screen` | `$screen_name`, `network` | The topmost screen changes, including back navigation and sheet dismissal |
| `network_changed` | `from_network`, `network` | The chosen network actually changes |
| `network_notify_requested` | `network` | Notify me is tapped for an upcoming network |
| `how_to_play_opened` | `network` | How to play becomes the topmost screen |

Screen names are `playing`, `archive`, `choose_network`, `results`, `how_to_play` and `statistics`. Network and screen values are enums, so free-form text cannot enter these events. The How to play and Statistics screens remain placeholders until their own tickets land.

The iOS result button uses `UIActivityViewController` because `ShareLink` has no completion callback. Only a successful completion sends `result_shared`; the Copy activity maps to `copied`, other activities to `shared`.

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
- Automatic screen views are off; the app sends its own typed `$screen` events.
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

`Packages/Analytics/Tests` checks exact event names and property dictionaries, the super properties, the SDK configuration and the `beforeSend` properties. `Packages/GameScreens/Tests` checks accepted guesses, silent restoration and failures, archive promotion and deduplication across reopening, and share completion. Tests send nothing to PostHog. Run them with `swift test --package-path Packages/Analytics` and `swift test --package-path Packages/GameScreens`.
