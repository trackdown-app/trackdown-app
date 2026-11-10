# iPhone Duo foundation

Build with Xcode 27.1 or later (iOS 27.1 SDK or later). CI selects Xcode 27.1; local verification used Xcode 27.2 / iOS 27.2. Keep `SDKROOT = iphoneos` so Xcode selects its installed SDK. The deployment target remains iOS 27.0; reserved-region queries are available from 27.1.

## Layout contract

- Compact horizontal size class uses the available width. Regular width uses the existing, Dynamic Type-scaled readable column. Neither uses device dimensions, orientation, or hinge angle to choose a screen.
- `reservedContent()` queries division and occlusion regions in its own `GeometryProxy` coordinates. `trackdownReservedRegions` exposes fold and camera frames, including inactive regions, to descendants. Active regions, expanded by their individual margins, displace the existing content into the largest unobstructed rectangle. This foundation keeps one content group together; later layout tickets can distribute content across both sides.
- System navigation and sheets keep their standard adaptive presentation. Foreground content respects the safe area on each edge independently; only backgrounds extend beyond it. Cards and custom glass surfaces use `ConcentricRectangle`; sheet content clips to the same shape and retains the system glass background.
- Resizing does not branch or replace navigation, model owners, sheet destinations, or scroll views. Today's query belongs to `AppModel.playing`; an archived query belongs to `ArchivedPuzzleView`'s state-owned model. The navigation path retains the selected archive puzzle; the root retains the presented sheet. Playing and archive views retain explicit `ScrollPosition` values.

References: [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) and [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/).

## Device Hub test plan

Use the iPhone Duo simulator in Device Hub. Do not reset app data between poses. If another thread owns the simulator, stop and release it from that thread's Device panel before continuing.

1. Open Trackdown on the outer display. Type a partial station name without submitting. Open, close, and reopen Duo. Confirm the exact query and suggestions survive and remain tappable.
2. Scroll the guess list away from the top, expand a trip, then open and close. Confirm the same vicinity remains visible and the trip remains expanded.
3. Open How to play, Statistics, and a finished game's results in turn. With each sheet open, close, open, rotate, and fold. Confirm the sheet remains presented, close buttons stay reachable, and corners follow the display.
4. Open Archive, scroll to an older month, select an unfinished puzzle, and type a partial guess. Repeat open/close/fold. Confirm the selected puzzle and query survive; Back returns to the archive's previous scroll vicinity.
5. Test flat inner display, partially folded book, partially folded table, and outer display. Rotate in each configuration. Confirm no controls cross the active fold or camera region. Check both leading and trailing system bars and safe areas, including Split View on either side.
6. Repeat in light/dark appearance, at accessibility text size, and with right-to-left layout. Confirm text and controls remain reachable through scrolling.

Record the actual app viewport separately from the native panel: a rotated inner panel can host a 951 x 669-point app window. The current simulator advertises an inner panel of 669 x 951 points and an outer panel of 466 x 678 points. These measurements are observations only, never layout inputs. Capture both displays to confirm their sizes when pose tooling supports it; the design canvas dimensions are estimates.

## Verification limitations

Local checks on 10 November 2026: strict swift-format lint, simulator build-for-testing, Release simulator build with warnings treated as errors, 32 DesignSystem tests, and 54 GameScreens tests. On the Duo inner display, the app launched full screen (2853 x 2007 pixels, or 951 x 669 points at 3x); How to play opened and dismissed, and Archive navigation pushed with a Back button. After importing the ignored secrets listed by `.worktreeinclude`, gameplay loaded successfully.

The first simulator pass exposed background clipping around the system bars. The screen backgrounds now sit outside the clipped reserved-content container. After installing and relaunching the final Release build, a Duo screenshot confirmed a uniform background behind the top, side, and bottom bars. The earlier simulator installation predated this correction.

Text entry failed with `TEXT_ENTRY_MISMATCH`, and the recommended delayed retry lost the runner transport and invalidated its session. Query retention and archive selection/scroll continuity still need the manual checks above. No guesses were submitted and app data was not reset.

The current agent-device pose command dispatches the request but cannot verify it with Xcode 27.2: its `devicectl device motion hinge-angle --device ...` invocation returns `Unknown option '--device'`. Automated hinge readback and claims about open/close/fold continuity are therefore skipped. Run the pose matrix above manually in Device Hub. Do not treat a dispatched pose request as a verified transition.

No web dev server or browser verification is needed for this native app.
