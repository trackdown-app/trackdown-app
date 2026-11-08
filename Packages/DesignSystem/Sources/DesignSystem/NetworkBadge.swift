import SwiftUI

/// The round country badge at the start of a network row, such as `NL` or `GB`.
///
/// The chosen network's badge is inked; every other network's is soft.
public struct NetworkBadge: View {
    private let code: String
    private let isInked: Bool

    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 44

    /// - Parameters:
    ///   - code: The country code, such as `NL`.
    ///   - isInked: Whether the badge is inked, for the chosen network.
    public init(code: String, isInked: Bool = false) {
        self.code = code
        self.isInked = isInked
    }

    public var body: some View {
        Text(verbatim: code)
            .font(TrackdownFont.subheadlineEmphasized)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isInked ? TrackdownColor.background : TrackdownColor.ink)
            .frame(width: size, height: size)
            .background { Circle().fill(isInked ? TrackdownColor.ink : TrackdownColor.soft) }
            .accessibilityHidden(true)
    }
}

/// The small "New" capsule next to a network that was added recently.
public struct NewBadge: View {
    public init() {}

    public var body: some View {
        Text("New", bundle: .module, comment: "Badge next to a rail network that was added recently.")
            .font(TrackdownFont.captionEmphasized)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(TrackdownColor.onLine)
            .background { Capsule().fill(TrackdownColor.line1) }
    }
}

#Preview("Network badges") {
    HStack(spacing: 14) {
        NetworkBadge(code: "NL", isInked: true)
        NetworkBadge(code: "GB")
        NewBadge()
    }
    .padding()
    .background { TrackdownColor.surface }
}
