import SwiftUI

/// A screen background with colored lines behind the content, so glass in previews has something to refract.
/// Registers the fonts, so previews render in Barlow.
struct GlassPreviewBackdrop<Content: View>: View {
    private let alignment: Alignment
    private let content: Content

    init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        TrackdownFont.register()
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: alignment) {
            TrackdownColor.background
                .ignoresSafeArea()
            VStack(alignment: .trailing, spacing: 28) {
                ForEach(0..<12, id: \.self) { row in
                    TrackdownColor.lines[row % 3]
                        .frame(height: 20)
                        .containerRelativeFrame(.horizontal) { width, _ in width * (0.3 + Double(row % 4) * 0.2) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHidden(true)
            content
                .padding(.vertical, 24)
        }
    }
}

#if os(iOS)
    /// The playing screen's layout with every glass component in place, to check placement and the scroll edges.
    private struct PlayingLayoutPreview: View {
        @State private var text = "Ams"
        @State private var selection: GuessSuggestion.ID? = "asd"

        init() {
            TrackdownFont.register()
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(verbatim: "Friday 6 November")
                            .font(TrackdownFont.largeTitle)
                        ForEach(0..<16, id: \.self) { row in
                            TrackdownColor.lines[row % 3]
                                .frame(height: 20)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .background(TrackdownColor.background)
                .trackdownScrollEdges()
                .safeAreaBar(edge: .bottom) {
                    GuessBar(
                        text: $text,
                        suggestions: [
                            GuessSuggestion(
                                id: "asd", name: "Amsterdam Centraal",
                                matchedRange: "Amsterdam Centraal".range(of: "Ams"), detail: "Noord-Holland"),
                            GuessSuggestion(
                                id: "asdz", name: "Amsterdam Zuid", matchedRange: "Amsterdam Zuid".range(of: "Ams"),
                                detail: "Noord-Holland"),
                        ],
                        selection: $selection
                    ) {}
                    .padding(.horizontal, 16)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NetworkPill(code: "NL", name: "Netherlands") {}
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                        } label: {
                            TrackdownIcon.archive.label
                        }
                        Button {
                        } label: {
                            TrackdownIcon.howToPlay.label
                        }
                        Button {
                        } label: {
                            TrackdownIcon.statistics.label
                        }
                    }
                }
            }
        }
    }

    #Preview("Playing layout") {
        PlayingLayoutPreview()
    }

    #Preview("Playing layout, dark") {
        PlayingLayoutPreview()
            .preferredColorScheme(.dark)
    }
#endif
