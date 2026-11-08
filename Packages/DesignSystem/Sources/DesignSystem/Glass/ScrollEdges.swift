import SwiftUI

extension View {
    /// The fades at the top and bottom of a screen, where content scrolls under the toolbar and the guess bar.
    ///
    /// Apply to the scroll view. The system draws the effect under bars only, so put floating controls in a toolbar or
    /// a `safeAreaBar(edge:)`, not in an overlay. Never draw these fades with a gradient.
    public func trackdownScrollEdges() -> some View {
        scrollEdgeEffectStyle(.soft, for: .vertical)
    }
}
