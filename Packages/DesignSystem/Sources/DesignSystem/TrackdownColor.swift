import SwiftUI

/// Brand colors from the Trackdown brand sheet.
///
/// Each color has a light and a dark value in `Colors.xcassets` and follows the system
/// appearance. Text pairs (``ink`` and ``muted`` on ``background`` or ``surface``, ``onLine`` on
/// the line colors) meet 4.5:1 contrast in both themes; `DesignSystemTests` checks this.
public enum TrackdownColor {
    /// Map paper: the screen background.
    public static let background = Color("Background", bundle: .module)
    /// Cards, list groups, input fields and the mystery-station bar.
    public static let surface = Color("Surface", bundle: .module)
    /// Primary text, guess dots and actions.
    public static let ink = Color("Ink", bundle: .module)
    /// Secondary text.
    public static let muted = Color("Muted", bundle: .module)
    /// Hairlines between rows and sections.
    public static let rule = Color("Rule", bundle: .module)
    /// Guesses not used yet in the progress track. Not for text.
    public static let empty = Color("Empty", bundle: .module)
    /// Time grid lines behind the trips. Not for text.
    public static let grid = Color("Grid", bundle: .module)

    /// The first train of a trip.
    public static let line1 = Color("Line1", bundle: .module)
    /// The train after the first change.
    public static let line2 = Color("Line2", bundle: .module)
    /// The train after the second change.
    public static let line3 = Color("Line3", bundle: .module)
    /// Labels drawn inside a line.
    public static let onLine = Color("OnLine", bundle: .module)

    /// The line colors in trip order: first train, after one change, after two changes.
    public static let lines: [Color] = [line1, line2, line3]
}
