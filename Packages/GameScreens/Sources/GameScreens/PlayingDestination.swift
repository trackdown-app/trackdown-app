import DesignSystem
import GameCore
import SwiftUI

/// Where the playing screen sends the player. The app decides how each one is shown.
public enum PlayingDestination: Sendable, Hashable, Identifiable {
    /// The archive of past puzzles.
    case archive
    /// The How to play sheet.
    case howToPlay
    /// The player's statistics.
    case statistics
    /// The network picker.
    case chooseNetwork
    /// Usage data preferences, also opened by the consent status toast.
    case privacy
    /// The Solved (or Missed) sheet of a finished game.
    case solved(GameKey)

    public var id: Self { self }

    /// The destination's name, for a placeholder until its screen is built.
    public var title: Text {
        switch self {
        case .archive: TrackdownIcon.archive.title
        case .howToPlay: TrackdownIcon.howToPlay.title
        case .statistics: TrackdownIcon.statistics.title
        case .chooseNetwork: Text("Choose network", bundle: .module, comment: "Title of the network picker.")
        case .privacy: Text("Privacy", bundle: .module, comment: "Title of the privacy settings screen.")
        case .solved: Text("Results", bundle: .module, comment: "Title of the sheet with a finished game's results.")
        }
    }
}
