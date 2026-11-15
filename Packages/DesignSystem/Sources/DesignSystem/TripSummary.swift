import Foundation
import GameCore

/// What a trip shows of one change's station.
enum ChangeStation: Sendable, Hashable {
    /// Not found yet: the player has not guessed it and the game is not revealed.
    case hidden
    /// A station of the network, by name.
    case named(String)
    /// A station outside the network's station list, such as Luxembourg on a Belgian trip. No player can guess it, so
    /// it only shows once the game is revealed, and the list has no name for its code.
    case abroad

    /// - Parameters:
    ///   - code: The change's station, `nil` while hidden.
    ///   - stationName: The name of a station of the network, `nil` for a code outside it.
    init(code: StationCode?, stationName: (StationCode) -> String?) {
        guard let code else {
            self = .hidden
            return
        }
        self = stationName(code).map(ChangeStation.named) ?? .abroad
    }
}

/// The line of text under a guess that says how the trip changes trains.
enum TripSummary: Sendable, Hashable {
    /// No changes.
    case direct
    /// One change, at this station.
    case change(at: ChangeStation)
    /// Two or more changes.
    case changes(Int)

    /// - Parameter changes: Each change's station in trip order.
    init(changes: [ChangeStation]) {
        switch changes.count {
        case 0: self = .direct
        case 1: self = .change(at: changes[0])
        default: self = .changes(changes.count)
        }
    }

    /// Shown under the station name: "Change at a hidden station".
    var text: String {
        switch self {
        case .direct: String(localized: .tripSummaryDirect)
        case .change(.named(let station)): String(localized: .tripSummaryChangeAt(station))
        case .change(.hidden): String(localized: .tripSummaryHiddenChange)
        case .change(.abroad): String(localized: .tripSummaryChangeAbroad)
        case .changes(let count): String(localized: .tripSummaryChanges(count))
        }
    }

    /// The end of a guess's VoiceOver label, in lower case to follow a comma: "change at a hidden station".
    var spokenText: String {
        switch self {
        case .direct: String(localized: .tripSummaryDirectSpoken)
        case .change(.named(let station)): String(localized: .tripSummaryChangeAtSpoken(station))
        case .change(.hidden): String(localized: .tripSummaryHiddenChangeSpoken)
        case .change(.abroad): String(localized: .tripSummaryChangeAbroadSpoken)
        // Starts with a number, so the on-screen text reads right after a comma too.
        case .changes: text
        }
    }
}
