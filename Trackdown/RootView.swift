import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Trackdown", systemImage: "tram.fill")
        }
    }
}

#Preview {
    RootView()
        .environment(AppModel(configuration: .fromMainBundle()))
}
