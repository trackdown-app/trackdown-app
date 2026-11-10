import SwiftUI

extension View {
    /// Animates changes only when the player has not requested reduced motion.
    public func trackdownAnimation<Value: Equatable>(value: Value) -> some View {
        modifier(AccessibleAnimation(value: value))
    }
}

private struct AccessibleAnimation<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .smooth, value: value)
    }
}
