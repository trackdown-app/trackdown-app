# iOS coding standards

How code in this repo is written. Every ticket follows these rules; a reviewer can point at a section here instead of re-arguing it.

Baseline (set in `Config/Base.xcconfig` and the package manifests): Xcode 27.1, iOS 27 deployment target, iOS 27.1 SDK, Swift 6 language mode, strict concurrency `complete`, iPhone only.

Because the deployment target is iOS 27, SDK 27 APIs are used directly. Do not add `if #available(iOS 27, *)` gates or pre-27 fallbacks.

## Swift 6 concurrency

- The build must have zero concurrency warnings. Do not silence them with `@preconcurrency`, `nonisolated(unsafe)` or `@unchecked Sendable` unless the PR explains why and links the underlying issue.
- **App target:** default actor isolation is `MainActor` (`SWIFT_DEFAULT_ACTOR_ISOLATION`) with approachable concurrency on. Types in `Trackdown/` are main-actor by default; mark work that must leave the main actor `nonisolated` or `@concurrent` explicitly.
- **Packages:** the manifests do not set a default isolation, so package code is nonisolated by default. Annotate UI-facing types (`@Observable` models, view helpers) with `@MainActor`. Keep pure logic in `GameCore` and value types in `TrackdownAPI` free of actor isolation and `Sendable`.
- Value types that cross isolation boundaries (API models, game state, configuration) are `struct`/`enum` and `Sendable`. Prefer value types over classes for data.
- Use structured concurrency: `async`/`await`, `async let`, task groups, and SwiftUI's `.task { }` / `.task(id:)` for view-driven work so it cancels with the view. No `DispatchQueue`, completion handlers or Combine in new code.
- Unstructured `Task { }` only for fire-and-forget from synchronous UI callbacks (for example a button action). Never `Task.detached` without a written reason.
- Shared mutable state that is not UI state lives in an `actor`.
- Long-running loops check `Task.isCancelled` or call `try Task.checkCancellation()`.

## Observable models

- Models use the `@Observable` macro from Observation. No `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` or `@EnvironmentObject`.
- Models are `final class`, `@MainActor` (implicit in the app target, explicit in packages).
- A view that owns a model holds it in `@State`. A view that only reads it takes a plain `let`/`var` property, or reads it from the environment.
- Share app-wide models through the environment by type: `.environment(model)` and `@Environment(AppModel.self) private var model`. See `TrackdownApp` and `AppModel`.
- Need a binding into an environment model? Use `@Bindable var model = model` inside `body`.
- Mark properties that must not trigger view updates (caches, task handles) `@ObservationIgnored`.

## `@State` macro (SDK 27)

In SDK 27, `@State` is a macro, not a property wrapper. It generates real backing storage, which changes the init rules.

- `@State` properties are `private`. They hold state the view owns; anything passed in from outside is a normal property or a `@Binding`.
- **Give a `@State` property an initial value at the declaration, or assign it in `init`. Never both.** Assigning in `init` when the declaration already has a value compiles in some orders but has no effect: `body` sees the declared value.

  ```swift
  // Wrong: body sees 0, and fails to compile if `title` is assigned after `counter`.
  struct ScoreView: View {
      let title: String
      @State private var counter = 0

      init(title: String, start: Int) {
          self.counter = start
          self.title = title
      }
  }

  // Right: no initial value at the declaration, assigned once in init.
  struct ScoreView: View {
      let title: String
      @State private var counter: Int

      init(title: String, start: Int) {
          self.title = title
          self.counter = start
      }
  }
  ```

- Do not fix "variable used before being initialized" by reordering assignments in `init`. Remove the initial value from the declaration instead.
- A `@State` value set in `init` is only the *initial* value. Later changes to the init argument do not reset it. If the view should follow the argument, it should not be `@State`; use the argument directly or `.onChange(of:)`.
- Do not stack another property wrapper on a `@State` property. Both synthesize `_name` storage and the build fails with "invalid redeclaration of synthesized property".
- Views with `@State` do not get a synthesized private memberwise init. If you need one (for example to call it from an `init` in an extension), write it out.

## `@ContentBuilder`

In SDK 27, SwiftUI's result builders (including `@ViewBuilder`) are unified under `@ContentBuilder`. Builder blocks are no longer constrained to `View`, which removes some overload resolution the compiler used to get for free.

- Pass views to `overlay` and `background` with the trailing-closure form: `.overlay { Color.blue.opacity(0.3) }`, not `.overlay(Color.blue.opacity(0.3))`. The argument form is ambiguous for `ShapeStyle` expressions with modifiers.
- Do not declare types in our packages that shadow SwiftUI names (`Color`, `Text`, `Image`, `Button`, `Label`, ...). `DesignSystem` tokens live in namespaced types (for example `TrackdownColor` or static members on an extension), so `Color.clear` stays unambiguous. If a clash cannot be avoided, qualify it: `SwiftUI.Color.clear`.
- Never spell `TupleView` or `TupleContent` in a generic parameter. Use `some View`.
- Never leave a builder body empty, including an `#if` without `#else`. Write `EmptyView()` explicitly. Empty bodies become ambiguous as soon as MapKit is in the module graph.
- Use `@ViewBuilder` on computed properties and functions that return `some View`. Keep `body` small; extract subviews into their own `View` types rather than long builder functions.

## Navigation

- One `NavigationStack` per navigation hierarchy, created at the root of that hierarchy (see `RootView`). Never nest a `NavigationStack` inside another, and never put one inside a pushed destination.
- Navigate with values: `NavigationLink(value:)` plus `.navigationDestination(for:)`. No `NavigationLink(destination:)` and no `isActive:`/`tag:` links. `NavigationView` is not used.
- Drive programmatic navigation with a `path` (`[Route]` of a `Hashable` route enum, or `NavigationPath`) owned by the model that owns that flow.
- Register `.navigationDestination(for:)` once per value type, on a view inside the stack that is always present (not inside a lazy container like `List` rows).
- `NavigationSplitView` is for multi-column layouts. v1 is iPhone only, so do not reach for it by default. If a screen ever needs it (for example the iPhone Duo inner display), it must collapse correctly to a single stack in compact width; test both.
- Use `.sheet(item:)` and `.fullScreenCover(item:)` for value-driven modals. `isPresented:` only when there is no value.

## Toolbars (SDK 27)

- Build toolbars with `ToolbarItem` / `ToolbarItemGroup` and semantic placements. `ForEach` works inside `toolbar { }` for dynamic items, and `EmptyView()` for an explicit empty branch.
- iPhone width is tight, so every toolbar with more than two items states which ones matter:
  - `.visibilityPriority(.high)` on items that must stay in the bar, `.visibilityPriority(.low)` on items that may overflow first. Relative priorities: `ToolbarItemVisibilityPriority(higherThan:)` / `(lowerThan:)`.
  - `ToolbarItem(placement: .topBarPinnedTrailing)` for the single trailing action that must never overflow.
  - `ToolbarOverflowMenu { }` for secondary actions that always belong in the overflow menu. Do not build a hand-rolled "..." `Menu` for this.
- Minimize bars on scroll with `.toolbarMinimizeBehavior(_:for:)` (`.automatic`, `.onScrollDown`, `.onScrollUp`, `.never`) on the scroll view. Use `.toolbarMinimizationSafeAreaAdjustment(_:for:)` if content should not follow the bar. Default to `.automatic` unless design asks otherwise.
- Use `.contentMarginsRemoved()` on a toolbar item that must sit flush (for example an avatar), not negative padding.
- Hide the status bar with `.toolbarVisibility(.hidden, for: .statusBar)`, not `statusBarHidden(_:)`.

## Alerts and confirmation dialogs (SDK 27)

- When an alert or dialog acts on a value (the puzzle to reset, the item to delete, an error to show), drive it from one optional with the `item:` overloads:

  ```swift
  @State private var puzzleToReset: Puzzle?

  content
      .confirmationDialog("Reset puzzle?", item: $puzzleToReset) { puzzle in
          Button("Reset", role: .destructive) { model.reset(puzzle) }
      } message: { puzzle in
          Text("Your progress on \(puzzle.title) will be lost.")
      }
  ```

  SwiftUI sets the binding back to `nil` on dismiss. `T` does not need to be `Identifiable`.
- Do not pair a separate `isPresented` Bool with `presenting:`, and do not use the old `Alert`-returning `alert(item:) { Alert(...) }`.
- `isPresented:` only for alerts that carry no value.
- Always give destructive buttons `role: .destructive` and add a `role: .cancel` button when there is more than one action.

## Testing

- New tests use Swift Testing: `import Testing`, `@Test`, `#expect`, `#require`, `@Suite`. No XCTest for new code; do not add tests to an `XCTestCase`. Existing XCTest code is migrated when it is touched.
- Tests live in each package's `Tests/<Package>Tests` target (see `TrackdownAPITests`, `AnalyticsTests`). Logic belongs in packages so it can be tested there.
- Name tests after the behavior: `@Test("Rejects a relative base URL")`.
- Use `#require` to unwrap or stop early, `#expect(throws:)` for errors, and parameterized `@Test(arguments:)` instead of loops inside one test.
- Tests are `async` where the code is; never `sleep` to wait for work. Use `confirmation { }` for callbacks.
- Mark tests that touch main-actor types `@MainActor`.
- UI tests (when added) are the only exception and may use XCUITest.

## Localization

- All user-facing text goes through a String Catalog (`Localizable.xcstrings`). No hard-coded strings that bypass it, including accessibility labels, alert titles and toolbar button titles.
- SwiftUI initializers that take a `LocalizedStringKey` (`Text("...")`, `Button("...")`, `Label("...", systemImage:)`) are extracted automatically (`SWIFT_EMIT_LOC_STRINGS = YES`). Outside views, use `String(localized:)` or `LocalizedStringResource`.
- Generated string symbols are on (`STRING_CATALOG_GENERATE_SYMBOLS = YES`); prefer them for keys defined manually in the catalog.
- Packages with UI keep their own `Localizable.xcstrings` and pass `bundle: .module`.
- Use interpolation, not concatenation, so translators see the whole sentence: `Text("\(count) stations left")`. Let the catalog handle plurals.
- Add a translator comment for any string whose meaning is not obvious from its text.
- Format numbers, dates and durations with `FormatStyle` (`.formatted()`), never by hand.
- Strings that are never shown to the user (log messages, analytics event names, API keys) use `verbatim:` or plain `String` and stay out of the catalog.

## Layout

- Adapt layout from the environment only: `@Environment(\.horizontalSizeClass)`, `@Environment(\.verticalSizeClass)`, `@Environment(\.dynamicTypeSize)`, and the size the parent proposes (`ViewThatFits`, `Layout`, `containerRelativeFrame`, `onGeometryChange`).
- Never use `UIScreen.main` (or any `UIScreen` bounds) to size or branch layout. It is wrong in multi-window and on iPhone Duo.
- Never check device orientation (`UIDevice.current.orientation`, interface orientation, "is landscape" from width > height) to choose a layout. On iPhone Duo the inner display ignores supported orientations, so orientation says nothing reliable about the available space. Ask for the size class or the actual size instead.
- Never branch on device model or screen size constants.
- Give a full-screen screen's content `readableWidth()` (from `DesignSystem`), inside its scroll view and on its floating bar, so it stays one readable column on the iPhone Duo inner display and in landscape.
- At accessibility text sizes, stack side-by-side text and controls (`dynamicTypeSize.isAccessibilitySize` with `AnyLayout`) instead of squeezing them. Drawings such as the trip line may stop growing at `.xxxLarge` with `.dynamicTypeSize(...)`; the text around them keeps scaling.
- Respect safe areas; use `safeAreaInset` / `safeAreaPadding` instead of hard-coded insets.
- Support Dynamic Type up to accessibility sizes. Use text styles (`.font(.body)`) and `DesignSystem` tokens, not fixed point sizes; use `@ScaledMetric` for custom dimensions.

## Liquid Glass

- Use system glass only:
  - Toolbars, tab bars, navigation bars and sheets get glass automatically. Do not cover them with custom backgrounds; avoid `.toolbarBackground` unless design requires it.
  - Buttons: `.buttonStyle(.glass)` for standard actions, `.buttonStyle(.glassProminent)` for the primary action on a screen.
  - Custom floating controls: `.glassEffect()` (with a shape or `.tint` when needed). Group neighboring glass elements in a `GlassEffectContainer` so they blend and morph together; use `glassEffectID` for transitions.
- Never fake glass: no `.ultraThinMaterial` / `.regularMaterial` backgrounds, `.blur` modifiers, `UIVisualEffectView` or semi-transparent fills meant to look like glass.
- Glass is for the navigation and controls layer floating above content, not for content itself (cards, list rows, game board). Do not stack glass on glass.
- Shared glass components belong in `DesignSystem`, so screens use one component rather than repeating modifiers.
- Check Reduce Transparency and Increase Contrast; system glass handles them, custom tints must stay legible.
