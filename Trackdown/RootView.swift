import Analytics
import DesignSystem
import GameCore
import GameScreens
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var destination: PlayingDestination?
    /// Whether the archive sidebar shows beside the puzzle, on a display wide enough for it.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// The active fold across the split view, as in the book pose of iPhone Duo.
    @State private var fold: TrackdownFold?
    @State private var incomingURL: URL?
    @AppStorage("hasSeenHowToPlay") private var hasSeenHowToPlay = false
    /// The answer just given in the consent prompt, while its toast shows.
    @State private var consentToast: AnalyticsConsent?

    var body: some View {
        navigation
            .glassSheet(item: $destination, detents: Self.detents(for:)) { destination in
                switch destination {
                case .solved(let key):
                    ResultsSheet(model: model.results(key)) {
                        self.destination = nil
                        openArchive()
                    } onNextPuzzle: {
                        self.destination = nil
                        model.path = []
                    }
                case .archive, .chooseNetwork, .privacy:
                    // Pushed onto the stack by `navigate(_:)`, never a sheet.
                    EmptyView()
                case .howToPlay:
                    HowToPlaySheet(settings: model.analyticsSettings, network: model.network)
                case .statistics:
                    StatisticsScreen(model: model.statistics())
                }
            }
            .consentToast($consentToast) {
                consentToast = nil
                navigate(.privacy)
            }
            .consentPrompt(isPresented: needsConsent, onChoose: choose)
            .onAppear {
                guard !hasSeenHowToPlay else { return }
                destination = .howToPlay
                hasSeenHowToPlay = true
            }
            // Loads and restores today's game, then picks up the next puzzle at `nextPuzzleAt` while the app is open.
            .task(id: model.network) {
                await model.games.followRollover(network: model.network)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                // A suspended app misses the rollover; catch up when it comes back.
                Task { _ = try? await model.games.rolloverIfNeeded(network: model.network) }
            }
            .onOpenURL { url in
                guard PuzzleLink(url: url) != nil else { return }
                destination = nil
                incomingURL = url
            }
            .task(id: incomingURL) {
                guard let incomingURL, let link = PuzzleLink(url: incomingURL) else { return }
                await model.open(link)
                if !Task.isCancelled { self.incomingURL = nil }
            }
            .onChange(of: screenEvent, initial: true) { _, event in
                model.analytics.capture(event)
                if case .screenViewed(.howToPlay, let network) = event {
                    model.analytics.capture(.howToPlayOpened(network: network))
                }
            }
    }

    /// Whether the display is wide enough for the archive as a sidebar beside the puzzle, as on the iPhone Duo inner
    /// display.
    private var showsSidebar: Bool { horizontalSizeClass == .regular }

    /// The archive as a sidebar beside the puzzle on a wide display; one stack, the archive pushed from the playing
    /// screen, on a narrow one. Both follow `model.path`, so opening or closing iPhone Duo keeps the open puzzle.
    @ViewBuilder
    private var navigation: some View {
        @Bindable var model = model
        if showsSidebar {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                ArchiveSidebarScreen(
                    model: model.archive(), selection: model.detailPuzzle?.number, onSelect: model.show
                ) {
                    withAnimation { columnVisibility = .detailOnly }
                }
                // A new network has a new archive.
                .id(model.network)
                .toolbar(.hidden, for: .navigationBar)
                .navigationSplitViewColumnWidth(min: sidebarWidth, ideal: sidebarWidth, max: sidebarWidth)
            } detail: {
                NavigationStack(path: $model.detailPath) {
                    // The selected puzzle replaces the column's root rather than being pushed, so it has no Back
                    // button: the sidebar is the way to another puzzle.
                    stackRoot(puzzle: model.detailPuzzle)
                }
            }
            .navigationSplitViewStyle(.balanced)
            .onFoldChange { fold = $0 }
            // The sidebar has its own Hide sidebar button. While it is hidden, the system's Show Sidebar toggle and the
            // playing screen's archive button bring it back.
            .toolbar(removing: .sidebarToggle)
        } else {
            NavigationStack(path: $model.path) {
                stackRoot(puzzle: nil)
            }
        }
    }

    /// The sidebar's width: up to a vertical fold, so the archive and the puzzle each get one side of a device held like
    /// a book; otherwise a fixed column.
    private var sidebarWidth: CGFloat {
        guard let fold, fold.axis == .vertical else { return 300 }
        return fold.span.lowerBound
    }

    /// Whether the archive sidebar is on screen beside the puzzle.
    private var isSidebarVisible: Bool { showsSidebar && columnVisibility != .detailOnly }

    /// The playing screen for `puzzle`, or today's when it is `nil`, with every screen a stack can push on top of it.
    private func stackRoot(puzzle: ArchivedPuzzle?) -> some View {
        Group {
            if let puzzle {
                ArchivedPuzzleView(
                    model: model.playing(puzzle), showsArchive: !isSidebarVisible, onNavigate: navigate
                )
                // Another puzzle is another screen, with its own scroll position.
                .id(puzzle)
            } else {
                PlayingView(model: model.playing, showsArchive: !isSidebarVisible, onNavigate: navigate)
            }
        }
        // The playing screen arranges itself around an active fold.
        .reservedContent(spreadsAcrossFold: true)
        .background { TrackdownColor.background.ignoresSafeArea() }
        .navigationDestination(for: Route.self) { route in
            Group {
                switch route {
                case .archive:
                    ArchiveScreen(model: model.archive(), onSelect: select) {
                        model.path.append(.chooseNetwork)
                    }
                case .archivedPuzzle(let puzzle):
                    ArchivedPuzzleView(model: model.playing(puzzle), showsArchive: true, onNavigate: navigate)
                case .chooseNetwork:
                    ChooseNetworkScreen(
                        model: model.chooseNetwork(), onChoose: model.choose, onNotify: model.notify)
                case .privacy:
                    PrivacyView(settings: model.analyticsSettings)
                }
            }
            .reservedContent(spreadsAcrossFold: route.isPuzzle)
            .background { TrackdownColor.background.ignoresSafeArea() }
        }
    }

    /// Whether to ask about usage data now: no answer yet, and no other sheet up. On first launch How to play
    /// comes first, so the prompt and its toast land on the playing screen.
    private var needsConsent: Bool {
        model.analyticsSettings.consent == .unanswered && destination == nil && hasSeenHowToPlay
    }

    /// Tracks the topmost destination, including system back navigation and sheet dismissal.
    private var screenEvent: AnalyticsEvent {
        if let destination {
            switch destination {
            case .solved(let key): return .screenViewed(.results, network: key.network)
            case .howToPlay: return .screenViewed(.howToPlay, network: model.network)
            case .statistics: return .screenViewed(.statistics, network: model.network)
            case .archive, .chooseNetwork, .privacy: break
            }
        }
        // Beside the sidebar, the archive is always on screen; the detail column says what is being looked at.
        switch showsSidebar ? model.detailPath.last : model.path.last {
        case .archive: return .screenViewed(.archive, network: model.network)
        case .chooseNetwork: return .screenViewed(.chooseNetwork, network: model.network)
        case .privacy: return .screenViewed(.privacy, network: model.network)
        case .archivedPuzzle, nil: return .screenViewed(.playing, network: model.network)
        }
    }
}

extension RootView {
    /// Pushes the archive and the network picker; opens every other destination as a sheet.
    fileprivate func navigate(_ destination: PlayingDestination) {
        switch destination {
        case .archive: openArchive()
        case .chooseNetwork: model.path.append(.chooseNetwork)
        case .privacy: model.path.append(.privacy)
        case .howToPlay, .statistics, .solved: self.destination = destination
        }
    }

    /// Shows the archive: the sidebar beside the open puzzle on a wide display, the Archive screen on the stack
    /// otherwise.
    fileprivate func openArchive() {
        if showsSidebar {
            withAnimation { columnVisibility = .all }
        } else {
            model.openArchive()
        }
    }

    /// The player answered the consent prompt.
    fileprivate func choose(_ consent: AnalyticsConsent) {
        model.analyticsSettings.setConsent(consent)
        // Nothing was sent before the answer, so the screen the player is on has not been counted yet.
        if consent == .allowed { model.analytics.capture(screenEvent) }
        consentToast = consent
    }

    /// An archive row was tapped: back to today's puzzle, a past puzzle to play, or a finished game's sheet.
    fileprivate func select(_ action: ArchiveRow.Action) {
        switch action {
        case .continueToday: model.path = []
        case .play(let puzzle): model.path.append(.archivedPuzzle(puzzle))
        case .results(let key): destination = .solved(key)
        }
    }

    /// The Solved sheet leaves the revealed game showing above it, and Statistics is no taller than its record; the
    /// others fill the screen.
    fileprivate static func detents(for destination: PlayingDestination) -> Set<PresentationDetent> {
        switch destination {
        case .solved: [.fraction(0.75), .large]
        case .howToPlay: [.medium, .large]
        case .statistics: [.fraction(0.6), .large]
        case .archive, .chooseNetwork, .privacy: [.large]
        }
    }
}

/// The Statistics sheet. Owns its model for as long as the sheet is up, so the record is read again every time
/// it opens.
private struct StatisticsScreen: View {
    @State private var model: StatisticsModel

    init(model: StatisticsModel) {
        self.model = model
    }

    var body: some View {
        StatisticsSheet(model: model)
    }
}

/// The Solved or Missed sheet. Owns its model for as long as the sheet is up.
private struct ResultsSheet: View {
    @State private var model: ResultsModel
    private let onOlderPuzzles: () -> Void
    private let onNextPuzzle: () -> Void

    init(model: ResultsModel, onOlderPuzzles: @escaping () -> Void, onNextPuzzle: @escaping () -> Void) {
        self.model = model
        self.onOlderPuzzles = onOlderPuzzles
        self.onNextPuzzle = onNextPuzzle
    }

    var body: some View {
        ResultsView(model: model, onOlderPuzzles: onOlderPuzzles, onNextPuzzle: onNextPuzzle)
    }
}

/// The network picker, pushed from the network pill. Owns its model for as long as it is on the stack.
private struct ChooseNetworkScreen: View {
    @State private var model: ChooseNetworkModel
    private let onChoose: (Network) -> Void
    private let onNotify: (UpcomingNetwork) -> Void

    init(
        model: ChooseNetworkModel,
        onChoose: @escaping (Network) -> Void,
        onNotify: @escaping (UpcomingNetwork) -> Void
    ) {
        self.model = model
        self.onChoose = onChoose
        self.onNotify = onNotify
    }

    var body: some View {
        ChooseNetworkView(model: model, onChoose: onChoose, onNotify: onNotify)
    }
}

/// The archive, pushed from the playing screen or the Missed sheet. Owns its model for as long as it is on the stack.
private struct ArchiveScreen: View {
    @State private var model: ArchiveModel
    private let onSelect: (ArchiveRow.Action) -> Void
    private let onChooseNetwork: () -> Void

    init(
        model: ArchiveModel,
        onSelect: @escaping (ArchiveRow.Action) -> Void,
        onChooseNetwork: @escaping () -> Void
    ) {
        self.model = model
        self.onSelect = onSelect
        self.onChooseNetwork = onChooseNetwork
    }

    var body: some View {
        ArchiveView(model: model, onSelect: onSelect, onChooseNetwork: onChooseNetwork)
    }
}

/// The archive as the sidebar beside the puzzle. Owns its model for as long as the network stays the same.
private struct ArchiveSidebarScreen: View {
    @State private var model: ArchiveModel
    private let selection: Int?
    private let onSelect: (ArchiveRow) -> Void
    private let onHide: () -> Void

    init(
        model: ArchiveModel,
        selection: Int?,
        onSelect: @escaping (ArchiveRow) -> Void,
        onHide: @escaping () -> Void
    ) {
        self.model = model
        self.selection = selection
        self.onSelect = onSelect
        self.onHide = onHide
    }

    var body: some View {
        ArchiveSidebar(model: model, selection: selection, onSelect: onSelect, onHide: onHide)
    }
}

/// The playing screen for a past puzzle, pushed from the archive or, beside the archive sidebar, at the root of the
/// detail column. Owns its model for as long as it is on the stack.
private struct ArchivedPuzzleView: View {
    @State private var model: PlayingModel
    private let showsArchive: Bool
    private let onNavigate: (PlayingDestination) -> Void

    init(model: PlayingModel, showsArchive: Bool, onNavigate: @escaping (PlayingDestination) -> Void) {
        self.model = model
        self.showsArchive = showsArchive
        self.onNavigate = onNavigate
    }

    var body: some View {
        PlayingView(model: model, showsArchive: showsArchive, onNavigate: onNavigate)
    }
}

#Preview {
    TrackdownFont.register()
    return RootView()
        .environment(AppModel(configuration: .fromMainBundle()))
}
