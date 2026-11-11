import DesignSystem
import SwiftUI

@main
struct TrackdownApp: App {
    // Keep live state shared by windows, while fixture launches avoid production storage and analytics.
    @State private var model: AppModel? =
        Self.accessibilityScreen == nil ? AppModel(configuration: .fromMainBundle()) : nil

    private static var accessibilityScreen: String? {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-accessibility-screen"),
                arguments.indices.contains(index + 1)
            else { return nil }
            return arguments[index + 1]
        #else
            return nil
        #endif
    }

    init() {
        TrackdownFont.register()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
                if let screen = Self.accessibilityScreen {
                    AccessibilityFixtureView(screen: screen)
                } else if let model {
                    RootView().environment(model)
                }
            #else
                if let model {
                    RootView().environment(model)
                }
            #endif
        }
    }
}
