/// The player's answer to the analytics question.
public enum AnalyticsConsent: Sendable, Equatable, CaseIterable {
    /// Not asked yet, or asked under an older consent text.
    case unanswered
    /// The player allowed usage data.
    case allowed
    /// The player declined usage data.
    case declined

    /// Version of the consent text the answer was given to. Raise it when the prompt's wording or
    /// what allowing permits changes. Matches the website's `CONSENT_TEXT_VERSION`.
    public static let textVersion = 1

    /// The `consent_analytics` value: `null` before an answer, then `true` or `false`.
    public var propertyValue: AnalyticsValue {
        switch self {
        case .unanswered: .null
        case .allowed: .bool(true)
        case .declined: .bool(false)
        }
    }
}
