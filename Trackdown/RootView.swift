import Analytics
import DesignSystem
import GameCore
import GameScreens
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @State private var destination: PlayingDestination?
    @AppStorage("hasSeenHowToPlay") private var hasSeenHowToPlay = false
    /// The answer just given in the consent prompt, while its toast shows.
    @State private var consentToast: AnalyticsConsent?

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            PlayingView(model: model.playing, onNavigate: navigate)
                .reservedContent()
                .background { TrackdownColor.background.ignoresSafeArea() }
                .navigationDestination(for: Route.self) { route in
                    Group {
                        switch route {
                        case .archive:
                            ArchiveScreen(model: model.archive(), onSelect: select) {
                                model.path.append(.chooseNetwork)
                            }
                        case .archivedPuzzle(let puzzle):
                            ArchivedPuzzleView(model: model.playing(puzzle), onNavigate: navigate)
                        case .chooseNetwork:
                            ChooseNetworkScreen(
                                model: model.chooseNetwork(), onChoose: model.choose, onNotify: model.notify)
                        case .privacy:
                            PrivacyView(settings: model.analyticsSettings)
                        }
                    }
                    .reservedContent()
                    .background { TrackdownColor.background.ignoresSafeArea() }
                }
        }
        .glassSheet(item: $destination, detents: Self.detents(for:)) { destination in
            switch destination {
            case .solved(let key):
                ResultsSheet(model: model.results(key)) {
                    self.destination = nil
                    model.openArchive()
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
        .onChange(of: screenEvent, initial: true) { _, event in
            model.analytics.capture(event)
            if case .screenViewed(.howToPlay, let network) = event {
                model.analytics.capture(.howToPlayOpened(network: network))
            }
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
        switch model.path.last {
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
        case .archive: model.openArchive()
        case .chooseNetwork: model.path.append(.chooseNetwork)
        case .privacy: model.path.append(.privacy)
        case .howToPlay, .statistics, .solved: self.destination = destination
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

/// The playing screen for a past puzzle, pushed from the archive. Owns its model for as long as it is on the stack.
private struct ArchivedPuzzleView: View {
    @State private var model: PlayingModel
    private let onNavigate: (PlayingDestination) -> Void

    init(model: PlayingModel, onNavigate: @escaping (PlayingDestination) -> Void) {
        self.model = model
        self.onNavigate = onNavigate
    }

    var body: some View {
        PlayingView(model: model, onNavigate: onNavigate)
    }
}

#Preview {
    TrackdownFont.register()
    return RootView()
        .environment(AppModel(configuration: .fromMainBundle()))
}
