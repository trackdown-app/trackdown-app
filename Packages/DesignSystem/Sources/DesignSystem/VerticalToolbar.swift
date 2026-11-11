import SwiftUI

/// Reads which edge the system draws the toolbar on when it turns it into a vertical bar, such as on iPhone Duo with
/// the status bar and Dynamic Island on the trailing edge. `nil` while the toolbar runs along the top.
///
/// The reader always builds the same view, so switching between a top and a vertical toolbar keeps the content's
/// state, scroll position and focus.
public struct VerticalToolbarReader<Content: View>: View {
    private let content: (HorizontalEdge?) -> Content

    public init(@ViewBuilder content: @escaping (HorizontalEdge?) -> Content) {
        self.content = content
    }

    public var body: some View {
        // The macOS target only supports host tests. Xcode 27.1 ships a macOS 27.0 SDK without this API.
        #if os(iOS)
            if #available(iOS 27.1, *) {
                ToolbarVerticalEdgeReader(content: content)
            } else {
                content(nil)
            }
        #else
            content(nil)
        #endif
    }
}

#if os(iOS)
    @available(iOS 27.1, *)
    private struct ToolbarVerticalEdgeReader<Content: View>: View {
        let content: (HorizontalEdge?) -> Content
        @Environment(\.toolbarVerticalEdge) private var edge

        var body: some View {
            content(edge)
        }
    }
#endif

extension View {
    /// Pads a column `length` on both sides, except on the side of a vertical toolbar.
    ///
    /// The safe area already reaches past a vertical toolbar and its margin: on iPhone Duo it covers the status bar,
    /// the bar and a gap, leaving the column about 10 pt from the glass. Padding on that side as well would push the
    /// column twice as far from the bar as from the opposite edge. With `toolbarEdge` `nil`, this is
    /// `.padding(.horizontal, length)`.
    public func horizontalPadding(_ length: CGFloat, verticalToolbar toolbarEdge: HorizontalEdge?) -> some View {
        padding(.leading, toolbarEdge == .leading ? 0 : length)
            .padding(.trailing, toolbarEdge == .trailing ? 0 : length)
    }
}
