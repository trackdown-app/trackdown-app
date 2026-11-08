import SwiftUI

/// The glass capsule at the top of the playing screen that shows the current network and opens the network picker.
///
/// Draws its own glass. In a toolbar, hide the item's shared background so the glass is not doubled:
/// `ToolbarItem(placement: .topBarLeading) { NetworkPill(...) }.sharedBackgroundVisibility(.hidden)`.
public struct NetworkPill: View {
    private let code: String
    private let name: String
    private let action: () -> Void

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 44

    /// - Parameters:
    ///   - code: The network's short code shown in the inked badge, such as `NL`.
    ///   - name: The network's localized name, such as `Netherlands`.
    ///   - action: Opens the network picker.
    public init(code: String, name: String, action: @escaping () -> Void) {
        self.code = code
        self.name = name
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(verbatim: code)
                    .font(TrackdownFont.captionEmphasized)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(TrackdownColor.background)
                    .background { Capsule().fill(TrackdownColor.ink) }
                Text(verbatim: name)
                    .font(TrackdownFont.calloutEmphasized)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .lineLimit(1)
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .frame(minHeight: height)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(TrackdownColor.ink)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(Text("Network: \(name). Change network", bundle: .module))
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
