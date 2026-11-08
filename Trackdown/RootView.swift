import DesignSystem
import GameCore
import GameScreens
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @State private var destination: PlayingDestination?

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            PlayingView(model: model.playing, onNavigate: navigate)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .archivedPuzzle(let puzzle):
                        ArchivedPuzzleView(model: model.playing(puzzle), onNavigate: navigate)
                    case .chooseNetwork:
                        ChooseNetworkScreen(
                            model: model.chooseNetwork(), onChoose: model.choose, onNotify: model.notify)
                    }
                }
        }
        .glassSheet(item: $destination, detents: Self.detents(for:)) { destination in
            switch destination {
            case .solved(let key):
                ResultsSheet(model: model.results(key)) {
                    self.destination = .archive
                } onNextPuzzle: {
                    self.destination = nil
                    model.path = []
                }
            case .chooseNetwork:
                // Pushed onto the stack by `navigate(_:)`, never a sheet.
                EmptyView()
            case .archive, .howToPlay, .statistics:
                // The archive, How to play and statistics are separate tickets; until they land each destination
                // opens an empty sheet with its title.
                VStack(alignment: .leading, spacing: 20) {
                    GlassSheetHeader { destination.title }
                    Spacer()
                }
                .padding(24)
            }
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
    }
}

extension RootView {
    /// Pushes the network picker; opens every other destination as a sheet.
    fileprivate func navigate(_ destination: PlayingDestination) {
        switch destination {
        case .chooseNetwork: model.path.append(.chooseNetwork)
        case .archive, .howToPlay, .statistics, .solved: self.destination = destination
        }
    }

    /// The Solved sheet leaves the revealed game showing above it; the others fill the screen.
    fileprivate static func detents(for destination: PlayingDestination) -> Set<PresentationDetent> {
        switch destination {
        case .solved: [.fraction(0.75), .large]
        case .archive, .howToPlay, .statistics, .chooseNetwork: [.large]
        }
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
