# Accessibility verification

Run the UI audit on the iPhone 18 Pro simulator:

```sh
xcodebuild -project Trackdown.xcodeproj -scheme Trackdown \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -skipPackagePluginValidation -parallel-testing-enabled NO \
  -only-testing:TrackdownUITests test
```

The XCTest target calls `performAccessibilityAudit()` on isolated, offline fixtures for Playing, How to play, Solved, Missed, Networks, Archive, consent and Privacy. It checks light and dark appearances at normal size and AX5, before and after scrolling. A separate audit checks Dynamic Type scaling: the scaling audit changes font sizes internally, so visual audits pin their requested size to keep issue frames and viewport bounds consistent. Fixtures use no production game storage or analytics token and are excluded from Release builds.

For scroll content, the audit ignores contrast and clipping reports only when the reported element matches a scroll descendant whose frame crosses the visible scroll viewport boundary. The viewport excludes overlapping native navigation bars, toolbars and search fields. Screenshots confirmed these reports sampled clipped or blurred, offscreen glyphs. Each exclusion records the element, viewport and overlapping bar bounds as a test attachment. Fully visible text and all other audit types remain checked.

Contrast findings on disabled buttons are also exempt, matching WCAG's exception for inactive controls. Enabled controls remain checked, and each inactive-button exemption is attached to the test result.

The fixtures exercise the production screens and models. They do not test live API integration, native sheet transitions, every scroll position, or actual VoiceOver gestures. Review those separately. Run the same target on iPhone Duo before claiming coverage of its outer and inner layouts.

`DesignSystemTests` checks every shipped text color pairing against WCAG's 4.5:1 contrast threshold in both appearances. Glass uses system materials, which supply the Reduce Transparency fallback. Custom guess, message and toast animations honor Reduce Motion.

Manual checks should include Reduce Motion and Reduce Transparency enabled in system settings, long station names, expanded trip details, the keyboard and matching stations at AX5, VoiceOver reading order and action hints, and sheet dismissal. The network toolbar pill displays a globe at accessibility sizes while retaining its full spoken label.
