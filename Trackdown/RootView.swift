import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Trackdown", systemImage: "tram.fill")
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

#Preview {
    RootView()
        .environment(AppModel(configuration: .fromMainBundle()))
}
