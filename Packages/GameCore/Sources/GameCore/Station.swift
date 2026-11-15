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

/// The language station names, provinces and shared results come in: the app's languages, which are also the API's
/// and trackdown.nl's.
public enum StationLocale: String, Sendable, Hashable, Codable, CaseIterable {
    case nl
    case en
    case de
    case fr

    /// The first supported language in the app's language preferences, falling back to English.
    public static var device: StationLocale {
        preferred(languages: Locale.preferredLanguages)
    }

    /// Matches the app's supported languages in preference order, including regional identifiers.
    public static func preferred(languages: [String]) -> StationLocale {
        for language in languages {
            switch Locale.Language(identifier: language).languageCode {
            case .dutch: return .nl
            case .english: return .en
            case .german: return .de
            case .french: return .fr
            default: continue
            }
        }
        return .en
    }
}
