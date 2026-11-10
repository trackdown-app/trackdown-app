import Foundation

/// Formats a trip time in minutes the way trackdown.nl does: `2h 25m`, `2h 02m`, `17m`.
///
/// The compact form uses `u` for Dutch hours and `h` for English hours. For
/// VoiceOver use ``spoken``, which spells the units out in the user's language.
///
/// ```swift
/// Text(145.formatted(.tripDuration))  // "2h 25m"
/// ```
public struct TripDurationFormatStyle: FormatStyle {
    public enum Width: Sendable, Hashable, Codable {
        /// `2h 25m`, as shown on screen.
        case compact
        /// `2 hours, 25 minutes` in the user's language, for accessibility labels.
        case spoken
    }

    public var width: Width
    public var locale: Locale

    public init(width: Width = .compact, locale: Locale = .autoupdatingCurrent) {
        self.width = width
        self.locale = locale
    }

    public func format(_ minutes: Int) -> String {
        let minutes = max(0, minutes)
        switch width {
        case .compact:
            let hours = minutes / 60
            let rest = minutes % 60
            guard hours > 0 else {
                return String(
                    localized: LocalizedStringResource(
                        "\(rest)m", locale: locale, bundle: .module,
                        comment: "Compact trip duration in minutes, under one hour."))
            }
            let padded = rest < 10 ? "0\(rest)" : "\(rest)"
            return String(
                localized: LocalizedStringResource(
                    "\(hours)h \(padded)m", locale: locale, bundle: .module,
                    comment: "Compact trip duration: hours, then minutes padded to two digits."))
        case .spoken:
            return Duration.seconds(minutes * 60)
                .formatted(.units(allowed: [.hours, .minutes], width: .wide).locale(locale))
        }
    }

    public func locale(_ locale: Locale) -> TripDurationFormatStyle {
        TripDurationFormatStyle(width: width, locale: locale)
    }
}

extension FormatStyle where Self == TripDurationFormatStyle {
    /// A trip time as on trackdown.nl: `2h 25m`, `17m`.
    public static var tripDuration: TripDurationFormatStyle { TripDurationFormatStyle() }

    /// A trip time with its units spelled out, for accessibility labels: `2 hours, 25 minutes`.
    public static var spokenTripDuration: TripDurationFormatStyle { TripDurationFormatStyle(width: .spoken) }
}
