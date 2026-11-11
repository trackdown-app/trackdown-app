import SwiftUI

/// The glass capsule at the top of the playing screen that shows the current network and opens the network picker.
///
/// Draws its own glass. In a toolbar, hide the item's shared background so the glass is not doubled:
/// `ToolbarItem(placement: .topBarLeading) { NetworkPill(...) }.sharedBackgroundVisibility(.hidden)`.
public struct NetworkPill: View {
    private let code: String
    private let name: String
    private let action: () -> Void
    private let compact: Bool

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameters:
    ///   - code: The network's short code shown in the inked badge, such as `NL`.
    ///   - name: The network's localized name, such as `Netherlands`.
    ///   - action: Opens the network picker.
    public init(code: String, name: String, compact: Bool = false, action: @escaping () -> Void) {
        self.code = code
        self.name = name
        self.action = action
        self.compact = compact
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if compact {
                    Image(systemName: "globe")
                        .font(.body.weight(.semibold))
                } else {
                    Text(verbatim: code)
                        .font(TrackdownFont.captionEmphasized)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundStyle(TrackdownColor.background)
                        .background { Capsule().fill(TrackdownColor.ink) }
                }
                if !compact && !dynamicTypeSize.isAccessibilitySize {
                    Text(verbatim: name)
                        .font(TrackdownFont.calloutEmphasized)
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .lineLimit(1)
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .frame(minHeight: height)
            .contentShape(.capsule)
            .accessibilityHidden(true)
        }
        .accessibilityLabel(Text("Network: \(name). Change network", bundle: .module))
        .buttonStyle(.plain)
        .foregroundStyle(TrackdownColor.ink)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// The network button's label where there is no room for the pill, such as a vertical toolbar: a globe, named for
/// VoiceOver and overflow menus. Put it in a toolbar `Button`, where the system draws the glass.
public struct NetworkLabel: View {
    private let name: String

    /// - Parameter name: The network's localized name, such as `Netherlands`.
    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        Label {
            Text("Network: \(name). Change network", bundle: .module)
        } icon: {
            Image(systemName: "globe")
        }
    }
}

#Preview("Network pill") {
    GlassPreviewBackdrop {
        NetworkPill(code: "NL", name: "Netherlands") {}
    }
}

#Preview("Network pill, dark") {
    GlassPreviewBackdrop {
        NetworkPill(code: "GB", name: "Great Britain") {}
    }
    .preferredColorScheme(.dark)
}
