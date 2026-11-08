import DesignSystem
import SwiftUI

@main
struct TrackdownApp: App {
    @State private var model = AppModel(configuration: .fromMainBundle())

    init() {
        TrackdownFont.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
