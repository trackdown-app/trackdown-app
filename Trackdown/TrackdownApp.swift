import SwiftUI

@main
struct TrackdownApp: App {
    @State private var model = AppModel(configuration: .fromMainBundle())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
