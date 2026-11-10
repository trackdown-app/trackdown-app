import SwiftUI

extension View {
    /// Presents the How to play and Solved sheets: a system sheet with its default glass background.
    ///
    /// Do not give the sheet content a background or `presentationBackground`; the glass is the background. Start the
    /// content with a ``GlassSheetHeader``.
    public func glassSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent> = [.large],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        glassSheet(item: item, detents: { _ in detents }, content: content)
    }

    /// Presents a glass sheet whose detents depend on the item, such as a Solved sheet that leaves the game showing
    /// above it.
    public func glassSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: @escaping (Item) -> Set<PresentationDetent>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { item in
            content(item)
                .reservedContent()
                .clipShape(ConcentricRectangle())
                .presentationDetents(detents(item))
                .presentationDragIndicator(.visible)
        }
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
