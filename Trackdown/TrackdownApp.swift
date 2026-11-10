import DesignSystem
import SwiftUI

@main
struct TrackdownApp: App {
    init() {
        TrackdownFont.register()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
                if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-accessibility-screen"),
                    ProcessInfo.processInfo.arguments.indices.contains(index + 1)
                {
                    AccessibilityFixtureView(screen: ProcessInfo.processInfo.arguments[index + 1])
                } else {
                    LiveAppView()
                }
            #else
                LiveAppView()
            #endif
        }
    }
}

private struct LiveAppView: View {
    @State private var model = AppModel(configuration: .fromMainBundle())

    var body: some View {
        RootView().environment(model)
    }
}
