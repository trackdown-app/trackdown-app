# Trackdown for iOS

Native SwiftUI app for [trackdown.nl](https://trackdown.nl). iPhone only for v1.

## Requirements

- Xcode 27.1 or later (iOS 27.1 SDK, needed for full-screen iPhone Duo)
- iOS 27 deployment target
- Swift 6 language mode, strict concurrency set to complete

## Build

1. Create your local secrets file and fill in the values:

   ```sh
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   ```

   | Setting | Used for |
   | --- | --- |
   | `TRACKDOWN_CLIENT_KEY` | `Trackdown-Client-Key` header on API calls |
   | `POSTHOG_PROJECT_TOKEN` | PostHog analytics; leave empty to disable |
   | `DEVELOPMENT_TEAM` | Signing for device builds |
   | `TRACKDOWN_API_BASE_URL` | Optional override of the API base URL |

   The app builds without this file, with an empty client key and analytics off.

2. Open `Trackdown.xcodeproj` and run the `Trackdown` scheme, or build from the command line:

   ```sh
   xcodebuild -project Trackdown.xcodeproj -scheme Trackdown \
     -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
   ```

3. Run the tests (Swift Testing suites in the local packages):

   ```sh
   xcodebuild -project Trackdown.xcodeproj -scheme Trackdown \
     -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
   ```

4. Lint with `swift-format` (ships with Xcode; config in `.swift-format`):

   ```sh
   xcrun swift-format lint --strict --recursive --parallel Trackdown Packages
   ```

   Fix formatting in place with `xcrun swift-format format --in-place --recursive --parallel Trackdown Packages`.

## CI

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`, on the `xcode-27` runner with Xcode 27.1 selected:

- **Lint**: `swift-format lint --strict`.
- **Build and test**: builds the app for the iOS Simulator with warnings treated as errors in the app target and our local packages, then runs all Swift Testing suites in the `Trackdown` scheme. SPM dependencies are cached, keyed on `Package.resolved` and the local `Package.swift` files.

New test targets must be added to the `Trackdown` scheme's Test action to run in CI.

## Layout

```
Trackdown/            App target: entry point and wiring only
Config/               xcconfigs and Info.plist keys
Packages/
  TrackdownAPI/       Client for trackdown.nl /api/v1
  GameCore/           Game rules, state and statistics
  DesignSystem/       Design tokens and Liquid Glass components
  Analytics/          Analytics protocol on top of PostHog
```

Feature code goes in a package. The app target only builds the configuration and passes it to the packages.

## Configuration

`Config/Debug.xcconfig` and `Config/Release.xcconfig` include `Base.xcconfig` first and the untracked `Secrets.xcconfig` last, so local values win. `Config/Info.plist` exposes the values to the app as `TrackdownAPIBaseURL`, `TrackdownClientKey`, `PostHogHost` and `PostHogProjectToken`, read by `AppConfiguration`.

In xcconfig files `//` starts a comment, so write URLs as `https:/$()/host/path`.
