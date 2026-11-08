/// Design tokens and Liquid Glass components shared by every screen.
///
/// Tokens live in namespaced types so they never shadow SwiftUI names:
/// - ``TrackdownColor``: brand colors with light and dark values.
/// - ``TrackdownFont``: the Barlow type scale, scaled with Dynamic Type.
/// - ``TrackdownImage``: the logo and track mark as vector images.
///
/// Liquid Glass components, drawn with system glass:
/// - ``GlassIconButton`` and ``GlassIconButtonGroup``: 44 pt circular icon buttons.
/// - ``NetworkPill``: the current network with its inked code badge.
/// - ``GuessBar``: the guess field, Guess button and ``GuessSuggestion`` list, morphing in one container.
/// - ``SwiftUI/View/glassSheet(item:detents:content:)`` and ``GlassSheetHeader``: system sheets with glass.
/// - ``SwiftUI/View/trackdownScrollEdges()``: scroll edge effects instead of gradient fades.
///
/// Call ``TrackdownFont/register()`` once at launch (and in previews) before using the fonts.
public enum DesignSystem {}
