import DesignSystem
import GameCore
import SwiftUI

/// The main screen: the day's header, every guess drawn as its trip to the mystery station, and the guess bar.
///
/// Plays today's puzzle, or a past one when its model was made with ``PlayedPuzzle/archive(_:)``. Put it inside a
/// `NavigationStack`, wrapped in `reservedContent(spreadsAcrossFold: true)`; it adds its own toolbar.
///
/// On iPhone Duo the screen spreads across an active fold. In the book pose the guess list stays on the leading side
/// and the guess field, its suggestions and the Guess button move together to the trailing side. In the tabletop pose
/// the clues fill the propped-up top half and every control, the puzzle actions included, moves to the bottom half.
public struct PlayingView: View {
    private let model: PlayingModel
    private let showsArchive: Bool
    private let onNavigate: (PlayingDestination) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.trackdownFoldSplit) private var foldSplit
    /// Whether this screen was pushed, and so has a Back button in its navigation bar.
    @Environment(\.isPresented) private var isPresented

    /// The tabletop pose: the puzzle actions sit with the other controls in the bottom half, not in the toolbar.
    private var isTabletop: Bool { foldSplit?.axis == .horizontal }

    /// - Parameters:
    ///   - model: The game to play.
    ///   - showsArchive: Whether the toolbar has an archive button. Leave it out while the archive is already on
    ///     screen beside the puzzle, as a sidebar.
    ///   - onNavigate: Opens the archive, How to play, statistics, network picker or Solved sheet.
    public init(
        model: PlayingModel,
        showsArchive: Bool = true,
        onNavigate: @escaping (PlayingDestination) -> Void
    ) {
        self.model = model
        self.showsArchive = showsArchive
        self.onNavigate = onNavigate
    }

    public var body: some View {
        // Where the status bar runs down a side, as on iPhone Duo in landscape, the system turns the toolbar into a
        // vertical bar on that side. The network pill does not fit there: its name moves into the header.
        VerticalToolbarReader { toolbarEdge in
            content(toolbarEdge: toolbarEdge)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { TrackdownColor.background.ignoresSafeArea() }
                .toolbar { toolbar(isVertical: toolbarEdge != nil) }
        }
        .toolbarTitleDisplayMode(.inline)
        // In the tabletop pose an empty navigation bar would be the only thing left in the top half. A pushed screen
        // keeps it for its Back button.
        .toolbarVisibility(isTabletop && !isPresented ? .hidden : .automatic, for: .topBar)
        .task(id: model.network) { await model.load() }
        .sensoryFeedback(trigger: model.lastGuess) { _, guess in
            guard let guess else { return nil }
            return guess.solved ? .success : .impact(weight: .medium)
        }
    }

    @ViewBuilder
    private func content(toolbarEdge: HorizontalEdge?) -> some View {
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
            PlayingBoard(
                model: model, toolbarEdge: toolbarEdge, foldSplit: foldSplit, showsArchive: showsArchive,
                onNavigate: onNavigate)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(isVertical: Bool) -> some ToolbarContent {
        // In the tabletop pose the board shows the puzzle actions in the bottom half instead.
        if !isTabletop {
            if isVertical {
                verticalToolbar
            } else {
                topToolbar
            }
        }
    }

    /// The puzzle actions as one vertical glass bar, symbols only, the network first.
    @ToolbarContentBuilder
    private var verticalToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .trailingBar) {
            // A past puzzle belongs to its network, so only today's puzzle can switch.
            if model.puzzle == .today {
                Button {
                    onNavigate(.chooseNetwork)
                } label: {
                    NetworkLabel(name: model.network.name)
                }
            }
            if showsArchive {
                Button {
                    onNavigate(.archive)
                } label: {
                    TrackdownIcon.archive.label
                }
            }
            Button {
                onNavigate(.statistics)
            } label: {
                TrackdownIcon.statistics.label
            }
            Button {
                onNavigate(.howToPlay)
            } label: {
                TrackdownIcon.howToPlay.label
            }
        }
    }

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        // A past puzzle belongs to its network; the back button takes the pill's place.
        if model.puzzle == .today {
            ToolbarItem(placement: .leadingBar) {
                NetworkPill(
                    code: model.network.code, name: model.network.name, compact: dynamicTypeSize.isAccessibilitySize
                ) {
                    onNavigate(.chooseNetwork)
                }
                // The bar proposes an icon-sized width; the pill needs room for the network's name.
                .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            .visibilityPriority(.high)
        }

        ToolbarItemGroup(placement: .trailingBar) {
            if showsArchive {
                Button {
                    onNavigate(.archive)
                } label: {
                    TrackdownIcon.archive.label
                }
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
        static var leadingBar: ToolbarItemPlacement { .topBarLeading }
        static var trailingBar: ToolbarItemPlacement { .topBarTrailing }
    #else
        static var leadingBar: ToolbarItemPlacement { .navigation }
        static var trailingBar: ToolbarItemPlacement { .primaryAction }
    #endif
}

extension ToolbarPlacement {
    /// The bar at the top of the screen: the navigation bar on iOS.
    #if os(iOS)
        static var topBar: ToolbarPlacement { .navigationBar }
    #else
        static var topBar: ToolbarPlacement { .windowToolbar }
    #endif
}

/// The loaded game: the clues (header and guess list) and the controls (guess bar, or See results).
///
/// Both always exist as the same two views; ``PlayingBoardLayout`` only moves them. Across a pose change the guess list
/// keeps its scroll position and expanded trips, and the guess field keeps its text and focus.
private struct PlayingBoard: View {
    @Bindable var model: PlayingModel
    /// The side of a vertical toolbar, which the column keeps clear of.
    let toolbarEdge: HorizontalEdge?
    /// The fold the board spreads across, if any.
    let foldSplit: TrackdownFoldSplit?
    let showsArchive: Bool
    let onNavigate: (PlayingDestination) -> Void
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isTabletop: Bool { foldSplit?.axis == .horizontal }

    /// The vertical toolbar each part sits beside. In the book pose the clues only reach the leading edge and the
    /// controls only the trailing edge; on the fold's side each gets the usual padding.
    private func toolbarEdge(for edge: HorizontalEdge) -> HorizontalEdge? {
        foldSplit?.axis == .vertical && toolbarEdge != edge ? nil : toolbarEdge
    }

    var body: some View {
        PlayingBoardLayout(split: foldSplit) {
            clues
            controls
        }
    }

    private var clues: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let game = model.game {
                    PlayingHeader(
                        title: model.date?.title(),
                        // Without the network pill, the header names the network.
                        network: toolbarEdge != nil ? model.network.name : nil,
                        puzzle: game.key.number,
                        currentGuess: model.currentGuess,
                        maxGuesses: game.maxGuesses,
                        used: game.guesses.count,
                        isPlaying: game.status == .playing
                    )
                } else {
                    EmptyView()
                }
                MysteryStationMarker(station: model.revealedStation)
                    .padding(.top, isTabletop ? 12 : 24)
                    .padding(.bottom, 8)
                GuessList(
                    rows: model.rows, arrangement: isTabletop ? .besideTrack : .stacked,
                    stationName: model.name(of:))
            }
            .horizontalPadding(16, verticalToolbar: toolbarEdge(for: .leading))
            .padding(.bottom, 24)
            .readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollPosition($scrollPosition)
        .trackdownScrollEdges()
        .frame(minHeight: 0)
        .clipped()
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if isTabletop {
                puzzleActions
                // The guess field rests at the bottom edge, the suggestions growing up from it.
                Spacer(minLength: 0)
            } else {
                EmptyView()
            }
            bottomBar
        }
        .horizontalPadding(16, verticalToolbar: toolbarEdge(for: .trailing))
        .padding(.top, isTabletop ? 8 : 0)
        .padding(.bottom, 8)
        .readableWidth()
    }

    /// The toolbar's actions, in the tabletop pose: the network pill on the leading side, the archive, How to play and
    /// statistics buttons on the trailing side.
    private var puzzleActions: some View {
        HStack(spacing: 12) {
            // A past puzzle belongs to its network, so only today's puzzle can switch.
            if model.puzzle == .today {
                NetworkPill(
                    code: model.network.code, name: model.network.name, compact: dynamicTypeSize.isAccessibilitySize
                ) {
                    onNavigate(.chooseNetwork)
                }
            }
            Spacer(minLength: 0)
            GlassIconButtonGroup {
                if showsArchive {
                    GlassIconButton(.archive) { onNavigate(.archive) }
                }
                GlassIconButton(.howToPlay) { onNavigate(.howToPlay) }
                GlassIconButton(.statistics) { onNavigate(.statistics) }
            }
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
            .trackdownAnimation(value: model.message)
        }
    }
}

/// Places the board's two parts, the clues and the controls, around the fold the screen spreads across.
///
/// - No fold: one column, the controls under the clues.
/// - Book pose (vertical fold): the clues fill the leading side; the controls sit at the bottom of the trailing side.
/// - Tabletop pose (horizontal fold): the clues fill the top half; the controls fill the bottom half.
///
/// The split's sides are in the coordinates of the reserved-content container, which the board fills.
private struct PlayingBoardLayout: Layout {
    let split: TrackdownFoldSplit?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let clues = subviews[0]
        let controls = subviews[1]
        guard let split else {
            let controlsHeight = min(
                controls.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height, bounds.height)
            clues.place(
                at: bounds.origin,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height - controlsHeight))
            controls.place(
                at: CGPoint(x: bounds.minX, y: bounds.maxY - controlsHeight),
                proposal: ProposedViewSize(width: bounds.width, height: controlsHeight))
            return
        }
        let first = split.first.offsetBy(dx: bounds.minX, dy: bounds.minY)
        let second = split.second.offsetBy(dx: bounds.minX, dy: bounds.minY)
        clues.place(at: first.origin, proposal: ProposedViewSize(first.size))
        switch split.axis {
        case .vertical:
            let controlsHeight = min(
                controls.sizeThatFits(ProposedViewSize(width: second.width, height: nil)).height, second.height)
            controls.place(
                at: CGPoint(x: second.minX, y: second.maxY - controlsHeight),
                proposal: ProposedViewSize(width: second.width, height: controlsHeight))
        case .horizontal:
            controls.place(at: second.origin, proposal: ProposedViewSize(second.size))
        }
    }
}

/// Every guess, newest first, each with its number and trip.
private struct GuessList: View {
    let rows: [GuessRow]
    let arrangement: TripLine.Arrangement
    let stationName: (StationCode) -> String

    var body: some View {
        VStack(spacing: 0) {
            Rule()
            ForEach(rows) { row in
                GuessRowView(row: row, arrangement: arrangement, stationName: stationName)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
                Rule()
            }
        }
    }
}

/// One guess. Tapping a wrong guess opens its trip ride by ride under the line, as trackdown.nl does on a touch
/// screen; tapping again closes it. The right guess has no trip to show.
private struct GuessRowView: View {
    let row: GuessRow
    let arrangement: TripLine.Arrangement
    let stationName: (StationCode) -> String

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var numberWidth: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if row.correct {
                summary
            } else {
                Button {
                    withAnimation(reduceMotion ? nil : .smooth) { isExpanded.toggle() }
                } label: {
                    summary.contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    Text(
                        "Shows the trip ride by ride", bundle: .module,
                        comment: "VoiceOver hint of a guess: tapping it opens its trip ride by ride."))
            }
            if isExpanded && !row.correct {
                TripDetails(station: row.station, steps: row.steps, stationName: stationName)
                    .padding(.leading, numberWidth + 8)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                EmptyView()
            }
        }
        .clipped()
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.number, format: .number)
                .font(TrackdownFont.title3)
                .monospacedDigit()
                .foregroundStyle(TrackdownColor.muted)
                .frame(minWidth: numberWidth, alignment: .leading)
                .accessibilityLabel(
                    Text("Guess \(row.number)", bundle: .module, comment: "VoiceOver label of a guess's number."))
            TripLine(station: row.station, steps: row.steps, arrangement: arrangement, stationName: stationName)
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

/// "Mystery station", above the column of mystery-station bars, or the station's name once the game is revealed. A
/// label alone, as on trackdown.nl: a "?" only ever marks a change the player has not found, never the mystery station.
private struct MysteryStationMarker: View {
    /// The mystery station's name, once revealed.
    let station: String?

    var body: some View {
        Group {
            if let station {
                Text(verbatim: station)
                    .font(TrackdownFont.title3)
            } else {
                Text(
                    "Mystery station", bundle: .module,
                    comment: "Label above the bars that stand for the mystery station."
                )
                .font(TrackdownFont.subheadlineEmphasized)
            }
        }
        .foregroundStyle(TrackdownColor.ink)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
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
struct ProblemView: View {
    /// What failed to load.
    enum Subject {
        case puzzle
        case archive
    }

    let problem: PlayingProblem
    var subject: Subject = .puzzle
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
            switch subject {
            case .puzzle:
                Text(
                    "The puzzle couldn't be loaded. Try again in a moment.", bundle: .module,
                    comment: "Description when the puzzle failed to load.")
            case .archive:
                Text(
                    "The archive couldn't be loaded. Try again in a moment.", bundle: .module,
                    comment: "Description when the list of past puzzles failed to load.")
            }
        }
    }
}
