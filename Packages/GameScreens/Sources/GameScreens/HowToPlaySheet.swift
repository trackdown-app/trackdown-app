import Analytics
import DesignSystem
import GameCore
import SwiftUI

/// Game instructions, an example clue, and the Privacy entry point.
public struct HowToPlaySheet: View {
    private let settings: AnalyticsSettings
    private let network: Network
    @State private var path: [PlayingDestination] = []
    @Environment(\.dismiss) private var dismiss

    public init(settings: AnalyticsSettings, network: Network) {
        self.settings = settings
        self.network = network
    }

    public var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 20) {
                GlassSheetHeader { TrackdownIcon.howToPlay.title }
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HowToPlayRules()
                        HowToPlayExample()
                        Button {
                            dismiss()
                        } label: {
                            Text(
                                "Play today's station", bundle: .module,
                                comment: "Dismisses How to play so the player can start the daily puzzle."
                            )
                            .font(TrackdownFont.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .tint(TrackdownColor.ink)
                        .foregroundStyle(TrackdownColor.background)
                        NavigationLink(value: PlayingDestination.privacy) {
                            Text("Privacy settings", bundle: .module, comment: "Opens Privacy from How to play.")
                                .font(TrackdownFont.calloutEmphasized)
                                .foregroundStyle(TrackdownColor.line1)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .trackdownScrollEdges()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
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

private struct HowToPlayRules: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HowToPlayRule(number: 1) {
                Text("Guess the mystery station.", bundle: .module, comment: "First rule of Trackdown.")
            }
            HowToPlayRule(number: 2) {
                Text(
                    "Each guess shows the fastest train journey from your station to the mystery station.",
                    bundle: .module, comment: "Second rule: guesses produce route clues.")
            }
            HowToPlayRule(number: 3) {
                Text(
                    "Use the travel times and changes to narrow it down. A new station every day!",
                    bundle: .module, comment: "Third rule: use the clues to solve the daily puzzle.")
            }
        }
    }
}

private struct HowToPlayRule<Content: View>: View {
    let number: Int
    @ViewBuilder let content: Content
    @ScaledMetric(relativeTo: .headline) private var badgeSize: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number, format: .number)
                .font(TrackdownFont.headline)
                .foregroundStyle(TrackdownColor.onLine)
                .frame(width: badgeSize, height: badgeSize)
                .background { Circle().fill(TrackdownColor.line1) }
            content
                .font(TrackdownFont.body)
                .foregroundStyle(TrackdownColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HowToPlayExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("For example", bundle: .module, comment: "Heading above the example train journey clue.")
                .font(TrackdownFont.title3)
                .foregroundStyle(TrackdownColor.ink)
                .accessibilityAddTraits(.isHeader)
            TripLine(
                station: "Maastricht",
                steps: [
                    .ride(train: "IC", minutes: 122),
                    .change(station: nil, minutes: 6),
                    .ride(train: "IC", minutes: 17),
                ],
                stationName: { $0.rawValue }
            )
            Text(
                "From Maastricht, ride an Intercity for 2 hours and 2 minutes, change at a hidden station with a 6-minute wait, then ride another Intercity for 17 minutes. The mystery station is at the end of the line.",
                bundle: .module,
                comment: "Explains the Maastricht example clue, including the hidden change and destination."
            )
            .font(TrackdownFont.callout)
            .foregroundStyle(TrackdownColor.muted)
            Text(
                "Guess a change station to reveal its name in earlier clues.", bundle: .module,
                comment: "Explains how guessing a hidden change station updates earlier clues."
            )
            .font(TrackdownFont.callout)
            .foregroundStyle(TrackdownColor.muted)
        }
        .padding(20)
        .background { ConcentricRectangle(corners: .concentric(minimum: .fixed(26))).fill(TrackdownColor.surface) }
        .backgroundStyle(TrackdownColor.surface)
    }
}
