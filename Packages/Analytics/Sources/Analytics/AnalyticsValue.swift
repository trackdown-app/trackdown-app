import Foundation

/// A value of an event property. Limited to what PostHog stores as-is, so nothing at a call site
/// can slip an arbitrary object into an event.
public enum AnalyticsValue: Sendable, Hashable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case null

    /// The value as the PostHog SDK takes it.
    var sdkValue: Any {
        switch self {
        case .string(let value): value
        case .int(let value): value
        case .bool(let value): value
        case .null: NSNull()
        }
    }
}

extension AnalyticsValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension AnalyticsValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension AnalyticsValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension AnalyticsValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
