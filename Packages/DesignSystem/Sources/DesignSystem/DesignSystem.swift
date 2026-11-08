/// Design tokens and Liquid Glass components shared by every screen.
///
/// Tokens live in namespaced types so they never shadow SwiftUI names:
/// - ``TrackdownColor``: brand colors with light and dark values.
/// - ``TrackdownFont``: the Barlow type scale, scaled with Dynamic Type.
/// - ``TrackdownImage``: the logo and track mark as vector images.
///
/// Components:
/// - ``TripLine``: one guess drawn as its train trip to the mystery station.
///
/// Call ``TrackdownFont/register()`` once at launch (and in previews) before using the fonts.
public enum DesignSystem {}
