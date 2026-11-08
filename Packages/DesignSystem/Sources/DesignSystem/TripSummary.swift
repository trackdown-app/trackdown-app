import Foundation

/// The line of text under a guess that says how the trip changes trains.
enum TripSummary: Sendable, Hashable {
    /// No changes.
    case direct
    /// One change, at the named station, or at a hidden one when the name is `nil`.
    case change(at: String?)
    /// Two or more changes.
    case changes(Int)

    /// - Parameter changeNames: The name of each change station in trip order, `nil` while hidden.
    init(changeNames: [String?]) {
        switch changeNames.count {
        case 0: self = .direct
        case 1: self = .change(at: changeNames[0])
        default: self = .changes(changeNames.count)
        }
    }

    /// Shown under the station name: "Change at a hidden station".
    var text: String {
        switch self {
        case .direct: String(localized: .tripSummaryDirect)
        case .change(let station?): String(localized: .tripSummaryChangeAt(station))
        case .change(nil): String(localized: .tripSummaryHiddenChange)
        case .changes(let count): String(localized: .tripSummaryChanges(count))
        }
    }

    /// The end of a guess's VoiceOver label, in lower case to follow a comma: "change at a hidden station".
    var spokenText: String {
        switch self {
        case .direct: String(localized: .tripSummaryDirectSpoken)
        case .change(let station?): String(localized: .tripSummaryChangeAtSpoken(station))
        case .change(nil): String(localized: .tripSummaryHiddenChangeSpoken)
        // Starts with a number, so the on-screen text reads right after a comma too.
        case .changes: text
        }
    }
}
