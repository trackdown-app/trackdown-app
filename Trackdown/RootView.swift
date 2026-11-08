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
            PlayingView(model: model.playing) { destination = $0 }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .archivedPuzzle(let puzzle):
                        ArchivedPuzzleView(model: model.playing(puzzle)) { destination = $0 }
                    }
                }
        }
        // The archive, How to play, statistics, network picker and Solved screens are separate tickets; until they
        // land each destination opens an empty sheet with its title.
        .glassSheet(item: $destination) { destination in
            VStack(alignment: .leading, spacing: 20) {
                GlassSheetHeader { destination.title }
                Spacer()
            }
            .padding(24)
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
