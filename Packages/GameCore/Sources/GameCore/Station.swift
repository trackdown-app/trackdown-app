import Foundation

/// A station a player can guess.
public struct Station: Sendable, Hashable, Codable, Identifiable {
    public var code: StationCode
    /// The station's name in the locale it was fetched in.
    public var name: String
    public var province: String

    public var id: StationCode { code }

    public init(code: StationCode, name: String, province: String) {
        self.code = code
        self.name = name
        self.province = province
    }
}

/// The language station names and provinces come in.
///
/// The API and trackdown.nl only come in Dutch and English, so this is narrower than the app's own languages: a
/// player whose app runs in German or French gets station names, and shared results, in the next of their preferred
/// languages that is Dutch or English.
public enum StationLocale: String, Sendable, Hashable, Codable, CaseIterable {
    case nl
    case en

    /// The first Dutch or English language in the app's language preferences, falling back to English.
    public static var device: StationLocale {
        preferred(languages: Locale.preferredLanguages)
    }

    /// Matches Dutch or English in preference order, including regional identifiers.
    public static func preferred(languages: [String]) -> StationLocale {
        for language in languages {
            switch Locale.Language(identifier: language).languageCode {
            case .dutch: return .nl
            case .english: return .en
            default: continue
            }
        }
        return .en
    }
}
