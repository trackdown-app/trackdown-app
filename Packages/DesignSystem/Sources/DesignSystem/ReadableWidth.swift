import SwiftUI

extension View {
    /// Keeps a screen's content in one readable column, centered in whatever width the parent proposes.
    ///
    /// On a phone in portrait the column is the full width. On a wide space, such as the iPhone Duo inner display or a
    /// phone in landscape, the column stops at a comfortable reading width so a trip line does not stretch across the
    /// whole display and a guess's name stays near its time. The limit grows with Dynamic Type.
    ///
    /// Apply it to the content inside a scroll view, so the scroll view (and its scroll edge effect) still fills the
    /// screen, and to a floating bar so it lines up with the content above it.
    public func readableWidth() -> some View {
        modifier(ReadableWidth())
    }
}

private struct ReadableWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var maxWidth: CGFloat = 640

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : maxWidth)
            .frame(maxWidth: .infinity)
    }
}
