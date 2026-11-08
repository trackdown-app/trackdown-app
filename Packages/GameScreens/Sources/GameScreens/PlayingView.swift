import DesignSystem
import GameCore
import SwiftUI

/// The main screen: the day's header, every guess drawn as its trip to the mystery station, and the guess bar.
///
/// Plays today's puzzle, or a past one when its model was made with ``PlayedPuzzle/archive(_:)``. Put it inside a
/// `NavigationStack`; it adds its own toolbar.
public struct PlayingView: View {
    private let model: PlayingModel
    private let onNavigate: (PlayingDestination) -> Void

    /// - Parameters:
    ///   - model: The game to play.
    ///   - onNavigate: Opens the archive, How to play, statistics, network picker or Solved sheet.
    public init(model: PlayingModel, onNavigate: @escaping (PlayingDestination) -> Void) {
        self.model = model
        self.onNavigate = onNavigate
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { TrackdownColor.background.ignoresSafeArea() }
            .toolbar { toolbar }
            .toolbarTitleDisplayMode(.inline)
            .task(id: model.network) { await model.load() }
            .sensoryFeedback(trigger: model.lastGuess) { _, guess in
                guard let guess else { return nil }
                return guess.solved ? .success : .impact(weight: .medium)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .loading where model.game?.trips == nil:
            ProgressView {
                Text("Loading puzzle", bundle: .module, comment: "Shown while today's puzzle loads.")
            }
            .foregroundStyle(TrackdownColor.muted)
        case .failed(let problem):
            ProblemView(problem: problem) {
                Task { await model.load() }
            }
        case .loading, .ready:
            PlayingBoard(model: model, onNavigate: onNavigate)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // A past puzzle belongs to its network; the back button takes the pill's place.
        if model.puzzle == .today {
            ToolbarItem(placement: .leadingBar) {
                NetworkPill(code: model.network.code, name: model.network.name) {
                    onNavigate(.chooseNetwork)
                }
                // The bar proposes an icon-sized width; the pill needs room for the network's name.
                .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            .visibilityPriority(.high)
        }

        ToolbarItemGroup(placement: .trailingBar) {
            Button {
                onNavigate(.archive)
            } label: {
                TrackdownIcon.archive.label
            }
            Button {
                onNavigate(.howToPlay)
            } label: {
                TrackdownIcon.howToPlay.label
            }
            Button {
                onNavigate(.statistics)
            } label: {
                TrackdownIcon.statistics.label
            }
        }
    }
}

extension ToolbarItemPlacement {
    // The macOS build only exists so the package's tests run on the host.
    #if os(iOS)
        fileprivate static var leadingBar: ToolbarItemPlacement { .topBarLeading }
        fileprivate static var trailingBar: ToolbarItemPlacement { .topBarTrailing }
    #else
        fileprivate static var leadingBar: ToolbarItemPlacement { .navigation }
        fileprivate static var trailingBar: ToolbarItemPlacement { .primaryAction }
    #endif
}

/// The loaded game: header, guess list and guess bar.
private struct PlayingBoard: View {
    @Bindable var model: PlayingModel
    let onNavigate: (PlayingDestination) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let game = model.game {
                    PlayingHeader(
                        title: model.date?.title(),
                        puzzle: game.key.number,
                        currentGuess: model.currentGuess,
                        maxGuesses: game.maxGuesses,
                        used: game.guesses.count,
                        isPlaying: game.status == .playing
                    )
                } else {
                    EmptyView()
                }
                MysteryStationMarker()
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                GuessList(rows: model.rows, stationName: model.name(of:))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .trackdownScrollEdges()
        .safeAreaBar(edge: .bottom) {
            bottomBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let game = model.game, game.isOver {
            Button {
                onNavigate(.solved(game.key))
            } label: {
                Text("See results", bundle: .module, comment: "Button under a finished game that opens its results.")
                    .font(TrackdownFont.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(TrackdownColor.ink)
            .foregroundStyle(TrackdownColor.background)
        } else {
            VStack(spacing: 10) {
                if let message = model.message {
                    GuessMessageView(message: message)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    EmptyView()
                }
                GuessBar(text: $model.query, suggestions: model.suggestions, selection: $model.selection) {
                    Task {
                        if await model.guess(), let key = model.key {
                            onNavigate(.solved(key))
                        }
                    }
                }
                .disabled(!model.canGuess || model.isSubmitting)
            }
            .animation(.smooth, value: model.message)
        }
    }
}

/// Every guess, newest first, each with its number and trip.
private struct GuessList: View {
    let rows: [GuessRow]
    let stationName: (StationCode) -> String

    var body: some View {
        VStack(spacing: 0) {
            Rule()
            ForEach(rows) { row in
                GuessRowView(row: row, stationName: stationName)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
                Rule()
            }
        }
    }
}

private struct GuessRowView: View {
    let row: GuessRow
    let stationName: (StationCode) -> String

    @ScaledMetric(relativeTo: .title2) private var numberWidth: CGFloat = 20

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.number, format: .number)
                .font(TrackdownFont.title3)
                .monospacedDigit()
                .foregroundStyle(TrackdownColor.muted)
                .frame(minWidth: numberWidth, alignment: .leading)
                .accessibilityLabel(
                    Text("Guess \(row.number)", bundle: .module, comment: "VoiceOver label of a guess's number."))
            TripLine(station: row.station, steps: row.steps, stationName: stationName)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(TrackdownColor.rule)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// "Mystery station ?", above the column of mystery-station bars.
private struct MysteryStationMarker: View {
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 24

    var body: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Text(
                "Mystery station", bundle: .module, comment: "Label above the bars that stand for the mystery station."
            )
            .font(TrackdownFont.subheadlineEmphasized)
            Text(verbatim: "?")
                .font(TrackdownFont.captionEmphasized)
                .foregroundStyle(TrackdownColor.background)
                .frame(width: size, height: size)
                .background { Circle().fill(TrackdownColor.ink) }
                .accessibilityHidden(true)
        }
        .foregroundStyle(TrackdownColor.ink)
    }
}

/// The inline message when a guess is refused.
private struct GuessMessageView: View {
    let message: GuessMessage

    var body: some View {
        Label {
            text
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .font(TrackdownFont.subheadlineEmphasized)
        .foregroundStyle(TrackdownColor.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var text: Text {
        switch message {
        case .unknownStation:
            Text("That's not a station on this network.", bundle: .module, comment: "A guess for an unknown station.")
        case .alreadyGuessed(let station):
            Text(
                "You already guessed \(station).", bundle: .module,
                comment: "A guess for a station guessed before. The argument is the station's name.")
        case .problem(.offline):
            Text(
                "You're offline. Your guess wasn't sent.", bundle: .module,
                comment: "A guess that could not reach the server.")
        case .problem(.updateRequired):
            Text(
                "Update Trackdown to keep playing.", bundle: .module,
                comment: "The server no longer accepts this version of the app.")
        case .problem(.rateLimited(let retryAfter)):
            Text(
                "Too many guesses. Try again in \(retryAfter.retryText()).", bundle: .module,
                comment: "Rate-limited guess. The argument is a wait such as \"30 seconds\".")
        case .problem(.unavailable):
            Text(
                "Your guess couldn't be sent. Try again.", bundle: .module,
                comment: "A guess that failed on the server.")
        }
    }
}

/// The loading failure: offline, an outdated app, rate limited, or a server error, with a retry.
private struct ProblemView: View {
    let problem: PlayingProblem
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                title
            } icon: {
                Image(systemName: systemImage)
            }
            .font(TrackdownFont.title)
        } description: {
            description
                .font(TrackdownFont.callout)
        } actions: {
            Button(action: retry) {
                Text("Try again", bundle: .module, comment: "Retries loading the puzzle.")
                    .font(TrackdownFont.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(TrackdownColor.ink)
            .foregroundStyle(TrackdownColor.background)
        }
        .foregroundStyle(TrackdownColor.ink)
    }

    private var systemImage: String {
        switch problem {
        case .offline: "wifi.slash"
        case .updateRequired: "arrow.down.app"
        case .rateLimited: "hourglass"
        case .unavailable: "exclamationmark.triangle"
        }
    }

    private var title: Text {
        switch problem {
        case .offline:
            Text("You're offline", bundle: .module, comment: "Title when the puzzle cannot load without a connection.")
        case .updateRequired:
            Text("Update Trackdown", bundle: .module, comment: "Title when the app version is no longer supported.")
        case .rateLimited:
            Text("Too many requests", bundle: .module, comment: "Title when the server asks the app to wait.")
        case .unavailable:
            Text("Something went wrong", bundle: .module, comment: "Title when the puzzle failed to load.")
        }
    }

    private var description: Text {
        switch problem {
        case .offline:
            Text(
                "Check your connection and try again.", bundle: .module,
                comment: "Description when the puzzle cannot load without a connection.")
        case .updateRequired:
            Text(
                "This version of the app is no longer supported. Update it from the App Store.", bundle: .module,
                comment: "Description when the app version is no longer supported.")
        case .rateLimited(let retryAfter):
            Text(
                "Try again in \(retryAfter.retryText()).", bundle: .module,
                comment: "Description when rate limited. The argument is a wait such as \"30 seconds\".")
        case .unavailable:
            Text(
                "The puzzle couldn't be loaded. Try again in a moment.", bundle: .module,
                comment: "Description when the puzzle failed to load.")
        }
    }
}
