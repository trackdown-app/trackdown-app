import CoreText
import Foundation
import SwiftUI

/// The Trackdown type scale: headings in Barlow Condensed, body text in Barlow.
///
/// Sizes are the values at the default Dynamic Type size; every font scales with the text style
/// it is relative to. Times and counts use ``time``, ``statistic`` and ``lineLabel``, which have
/// tabular figures so digits line up and do not jump while a value changes. For any other font
/// showing a number, add `.monospacedDigit()`.
public enum TrackdownFont {
    /// Registers the bundled Barlow fonts for this process. Call once at launch and in previews;
    /// later calls do nothing.
    public static func register() {
        _ = registration
    }

    private static let registration: Void = {
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        assert(!urls.isEmpty, "DesignSystem bundle has no fonts")
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
                assert(
                    code == CTFontManagerError.alreadyRegistered.rawValue,
                    "Could not register \(url.lastPathComponent)"
                )
            }
        }
    }()

    // MARK: Headings (Barlow Condensed)

    /// Station name on the solved sheet.
    public static let display = font(.condensedExtraBold, size: 44, relativeTo: .largeTitle)
    /// Screen title.
    public static let largeTitle = font(.condensedExtraBold, size: 40, relativeTo: .largeTitle)
    /// Sheet title.
    public static let title = font(.condensedExtraBold, size: 36, relativeTo: .title)
    /// Guessed station name.
    public static let title2 = font(.condensedBold, size: 26, relativeTo: .title2)
    /// Row title and small heading.
    public static let title3 = font(.condensedBold, size: 22, relativeTo: .title3)
    /// Statistic value, with tabular figures.
    public static let statistic = font(.condensedBold, size: 32, relativeTo: .title).monospacedDigit()

    // MARK: Body (Barlow)

    /// Emphasized body text and button titles.
    public static let headline = font(.semiBold, size: 17, relativeTo: .headline)
    /// Body text.
    public static let body = font(.regular, size: 17, relativeTo: .body)
    /// Text typed into a field.
    public static let input = font(.medium, size: 18, relativeTo: .body)
    /// Introductions and descriptions.
    public static let callout = font(.regular, size: 16, relativeTo: .callout)
    /// Emphasized callout, such as the network picker.
    public static let calloutEmphasized = font(.semiBold, size: 16, relativeTo: .callout)
    /// Secondary lines and section headers.
    public static let subheadline = font(.regular, size: 15, relativeTo: .subheadline)
    /// Emphasized subheadline, such as a label next to a control.
    public static let subheadlineEmphasized = font(.semiBold, size: 15, relativeTo: .subheadline)
    /// Trip summary under a guess.
    public static let footnote = font(.regular, size: 14, relativeTo: .footnote)
    /// Small labels.
    public static let caption = font(.regular, size: 13, relativeTo: .caption)
    /// Emphasized small labels, such as weekdays.
    public static let captionEmphasized = font(.semiBold, size: 13, relativeTo: .caption)

    // MARK: Figures (Barlow, tabular)

    /// Trip time next to a guess, with tabular figures.
    public static let time = font(.semiBold, size: 17, relativeTo: .headline).monospacedDigit()
    /// Train and time label inside a line, with tabular figures.
    public static let lineLabel = font(.bold, size: 12, relativeTo: .caption2).monospacedDigit()
    /// The "?" in a hidden change's marker beside a trip's rides, sized to sit inside the 18-point ring with room to
    /// spare. Scales with the subheadline style, as the marker does.
    static let hiddenChangeMark = font(.bold, size: 10, relativeTo: .subheadline)

    // MARK: Faces

    /// PostScript names of the bundled faces.
    enum Face: String, CaseIterable {
        case regular = "Barlow-Regular"
        case medium = "Barlow-Medium"
        case semiBold = "Barlow-SemiBold"
        case bold = "Barlow-Bold"
        case extraBold = "Barlow-ExtraBold"
        case condensedMedium = "BarlowCondensed-Medium"
        case condensedSemiBold = "BarlowCondensed-SemiBold"
        case condensedBold = "BarlowCondensed-Bold"
        case condensedExtraBold = "BarlowCondensed-ExtraBold"
    }

    private static func font(_ face: Face, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(face.rawValue, size: size, relativeTo: style)
    }
}
