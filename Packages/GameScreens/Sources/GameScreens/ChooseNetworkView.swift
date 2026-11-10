import DesignSystem
import GameCore
import SwiftUI

/// The Choose network screen: every playable network with its streak, the networks still to come, and a search field
/// at the bottom that filters both.
///
/// Push it onto a `NavigationStack`; the system's glass back button returns to the playing screen.
public struct ChooseNetworkView: View {
    @Bindable private var model: ChooseNetworkModel
    private let onChoose: (Network) -> Void
    private let onNotify: (UpcomingNetwork) -> Void

    /// - Parameters:
    ///   - model: The networks to list.
    ///   - onChoose: Switches the game to the network and goes back to the playing screen.
    ///   - onNotify: The player asked to hear when a network still to come comes out.
    public init(
        model: ChooseNetworkModel,
        onChoose: @escaping (Network) -> Void,
        onNotify: @escaping (UpcomingNetwork) -> Void
    ) {
        self.model = model
        self.onChoose = onChoose
        self.onNotify = onNotify
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if model.isEmpty {
                    noMatches
                } else {
                    EmptyView()
                }
                if !model.networks.isEmpty {
                    NetworkGroup {
                        ForEach(model.networks) { row in
                            NetworkRowView(row: row) { onChoose(row.network) }
                        }
                    }
                } else {
                    EmptyView()
                }
                if !model.upcoming.isEmpty {
                    upcoming
                } else {
                    EmptyView()
                }
                suggestLink
            }
            // Full width, so a short search result does not shrink the column and center it.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .trackdownScrollEdges()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TrackdownColor.background.ignoresSafeArea() }
        .searchable(
            text: $model.query,
            prompt: Text("Search countries", bundle: .module, comment: "Placeholder of the network search field.")
        )
        .task { await model.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Networks", bundle: .module, comment: "Title of the network picker.")
                .font(TrackdownFont.largeTitle)
                .foregroundStyle(TrackdownColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Each network has its own daily station and its own streak.", bundle: .module,
                comment: "Introduction under the title of the network picker."
            )
            .font(TrackdownFont.callout)
            .foregroundStyle(TrackdownColor.muted)
        }
    }

    private var upcoming: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coming next", bundle: .module, comment: "Header above the rail networks still to come.")
                .font(TrackdownFont.subheadlineEmphasized)
                .foregroundStyle(TrackdownColor.muted)
                .padding(.horizontal, 16)
                .accessibilityAddTraits(.isHeader)
            NetworkGroup {
                ForEach(model.upcoming) { network in
                    UpcomingRowView(network: network, isNotified: model.notified.contains(network)) {
                        model.notify(network)
                        onNotify(network)
                    }
                }
            }
        }
    }

    private var noMatches: some View {
        Text(
            "No networks match “\(model.query)”.", bundle: .module,
            comment: "Shown when the network search matches nothing. The argument is what was typed."
        )
        .font(TrackdownFont.callout)
        .foregroundStyle(TrackdownColor.muted)
    }

    private var suggestLink: some View {
        Link(destination: Self.suggestURL) {
            Text(
                "Suggest a network, like a metro system", bundle: .module,
                comment: "Link that opens an email to suggest a new rail network."
            )
            .font(TrackdownFont.calloutEmphasized)
            .foregroundStyle(TrackdownColor.line1)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
        }
    }

    /// An email to the address the website lists for contact.
    static let suggestURL = URL(string: "mailto:info@trackdown.nl?subject=Network%20suggestion")!
}

/// Rows on one rounded surface, with a hairline between rows.
private struct NetworkGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Group(subviews: content) { subviews in
            VStack(spacing: 0) {
                ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                    if index > 0 {
                        Rectangle()
                            .fill(TrackdownColor.rule)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    } else {
                        EmptyView()
                    }
                    subview
                }
            }
        }
        .background { RoundedRectangle(cornerRadius: 26).fill(TrackdownColor.surface) }
        .clipShape(.rect(cornerRadius: 26))
    }
}

/// A playable network: badge, name, what it covers with the streak, and a checkmark on the chosen one.
private struct NetworkRowView: View {
    let row: NetworkRow
    let action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var checkSize: CGFloat = 24

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                NetworkBadge(code: row.code, isInked: row.isChosen)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: row.name)
                        .font(TrackdownFont.title3)
                        .foregroundStyle(TrackdownColor.ink)
                    subtitle
                        .font(TrackdownFont.subheadline)
                        .foregroundStyle(TrackdownColor.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if row.isNew {
                    NewBadge()
                } else {
                    EmptyView()
                }
                if row.isChosen {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(TrackdownColor.onLine)
                        .frame(width: checkSize, height: checkSize)
                        .background { Circle().fill(TrackdownColor.line1) }
                        .accessibilityHidden(true)
                } else {
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(row.isChosen ? .isSelected : [])
    }

    private var subtitle: Text {
        if let streak = row.streak, streak > 0 {
            Text(
                "\(row.detail), streak \(streak)", bundle: .module,
                comment:
                    "Under a network's name: what it covers, then the current streak, such as \"All railway stations, streak 7\"."
            )
        } else {
            Text(verbatim: row.detail)
        }
    }
}

/// A network still to come, with its Notify me button.
private struct UpcomingRowView: View {
    let network: UpcomingNetwork
    let isNotified: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            NetworkBadge(code: network.code)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: network.name)
                    .font(TrackdownFont.title3)
                    .foregroundStyle(TrackdownColor.ink)
                Text(verbatim: network.detail)
                    .font(TrackdownFont.footnote)
                    .foregroundStyle(TrackdownColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button(action: action) {
                Group {
                    if isNotified {
                        Label {
                            Text("Noted", bundle: .module, comment: "Notify me button once tapped.")
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text("Notify me", bundle: .module, comment: "Button to hear when a rail network comes out.")
                    }
                }
                .font(TrackdownFont.calloutEmphasized)
                .foregroundStyle(isNotified ? TrackdownColor.muted : TrackdownColor.line1)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(isNotified)
            .accessibilityLabel(
                isNotified
                    ? Text(
                        "Noted: \(network.name)", bundle: .module,
                        comment:
                            "VoiceOver label of a tapped Notify me button. The argument is a country, such as Belgium.")
                    : Text(
                        "Notify me about \(network.name)", bundle: .module,
                        comment: "VoiceOver label of Notify me. The argument is a country, such as Belgium."))
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
    }
}
