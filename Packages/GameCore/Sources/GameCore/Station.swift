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
public enum StationLocale: String, Sendable, Hashable, Codable, CaseIterable {
    case nl
    case en

    /// Dutch when the device's first preferred language is Dutch, English otherwise.
    public static var device: StationLocale {
        preferred(languages: Locale.preferredLanguages)
    }

    /// Dutch when the first of `languages` (BCP 47 identifiers, such as `nl-BE`) is Dutch, English otherwise.
    public static func preferred(languages: [String]) -> StationLocale {
        guard let first = languages.first else { return .en }
        return Locale.Language(identifier: first).languageCode == .dutch ? .nl : .en
    }
}
