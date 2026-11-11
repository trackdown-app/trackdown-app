import SwiftUI

/// A height a glass sheet stops at as a bottom sheet, on a narrow display. A wide display shows a centred form sheet
/// instead.
public enum GlassSheetDetent: Hashable, Sendable {
    /// About half the screen.
    case medium
    /// Nearly the whole screen.
    case large
    /// A share of the largest height, such as 0.75.
    case fraction(CGFloat)

    /// The share of the largest height, to order the detents by.
    var share: CGFloat {
        switch self {
        case .medium: 0.5
        case .large: 1
        case .fraction(let share): share
        }
    }

    var presentationDetent: PresentationDetent {
        switch self {
        case .medium: .medium
        case .large: .large
        case .fraction(let share): .fraction(share)
        }
    }
}

extension View {
    /// Presents the How to play and Solved sheets: a system sheet with its default glass background.
    ///
    /// A narrow display, such as an iPhone, shows a bottom sheet at `detents`. A wide one, such as the iPhone Duo inner
    /// display, shows a centred form sheet, which the system keeps clear of an active fold. Opening or closing iPhone
    /// Duo turns one into the other, keeping the sheet up.
    ///
    /// Do not give the sheet content a background or `presentationBackground`; the glass is the background. Start the
    /// content with a ``GlassSheetHeader``.
    public func glassSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: Set<GlassSheetDetent> = [.large],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        glassSheet(item: item, detents: { _ in detents }, content: content)
    }

    /// Presents a glass sheet whose detents depend on the item, such as a Solved sheet that leaves the game showing
    /// above it.
    public func glassSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: @escaping (Item) -> Set<GlassSheetDetent>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
            // SwiftUI's sheet ignores `presentationSizing(.form)` on iPhone, even on the iPhone Duo inner display.
            background {
                FormSheetPresenter(item: item, detents: detents) { item in
                    GlassSheetBody(content: content(item))
                }
            }
        #else
            // The macOS build only exists so the package's tests run on the host.
            sheet(item: item) { item in
                GlassSheetBody(content: content(item))
                    .presentationDetents(Set(detents(item).map(\.presentationDetent)))
            }
        #endif
    }
}

/// A glass sheet's content, clear of reserved regions, its corners following the sheet's.
private struct GlassSheetBody<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .reservedContent()
            .clipShape(ConcentricRectangle())
    }
}

/// The top of a glass sheet: the sheet title and a glass close button that dismisses the sheet.
public struct GlassSheetHeader<Title: View>: View {
    private let title: Title

    @Environment(\.dismiss) private var dismiss

    /// - Parameter title: The sheet title. Text gets ``TrackdownFont/title``; set another font for the Solved sheet.
    public init(@ViewBuilder title: () -> Title) {
        self.title = title()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            title
                .font(TrackdownFont.title)
                .foregroundStyle(TrackdownColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            GlassIconButton(.close) { dismiss() }
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
        }
    }
}

private struct GlassSheetPreview: View {
    struct Sheet: Identifiable {
        let id = 1
    }

    @State private var sheet: Sheet? = Sheet()

    var body: some View {
        GlassPreviewBackdrop {
            Button {
                sheet = Sheet()
            } label: {
                Text(verbatim: "Show sheet")
            }
            .buttonStyle(.glass)
        }
        .glassSheet(item: $sheet, detents: [.fraction(0.75), .large]) { _ in
            VStack(alignment: .leading, spacing: 20) {
                GlassSheetHeader { Text(verbatim: "How to play") }
                Text(verbatim: "Guess any station in the Netherlands.")
                    .font(TrackdownFont.body)
                Spacer()
            }
            .padding(24)
        }
    }
}

#Preview("Sheet") {
    GlassSheetPreview()
}

#Preview("Sheet, dark") {
    GlassSheetPreview()
        .preferredColorScheme(.dark)
}
