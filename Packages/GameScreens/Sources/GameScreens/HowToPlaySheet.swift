import Analytics
import DesignSystem
import GameCore
import SwiftUI

/// The How to play sheet's navigation and Privacy entry point. Instructions arrive with #25.
public struct HowToPlaySheet: View {
    private let settings: AnalyticsSettings
    private let network: Network
    @State private var path: [PlayingDestination] = []

    public init(settings: AnalyticsSettings, network: Network) {
        self.settings = settings
        self.network = network
    }

    public var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 20) {
                GlassSheetHeader { TrackdownIcon.howToPlay.title }
                Spacer()
                NavigationLink(value: PlayingDestination.privacy) {
                    Text("Privacy settings", bundle: .module, comment: "Opens Privacy from How to play.")
                        .font(TrackdownFont.calloutEmphasized)
                        .foregroundStyle(TrackdownColor.line1)
                        .frame(minHeight: 44)
                }
            }
            .padding(24)
            .navigationDestination(for: PlayingDestination.self) { destination in
                switch destination {
                case .privacy: PrivacyView(settings: settings)
                default: EmptyView()
                }
            }
        }
        .onChange(of: path.isEmpty) { _, isEmpty in
            settings.client.capture(.screenViewed(isEmpty ? .howToPlay : .privacy, network: network))
            if isEmpty { settings.client.capture(.howToPlayOpened(network: network)) }
        }
    }
}
