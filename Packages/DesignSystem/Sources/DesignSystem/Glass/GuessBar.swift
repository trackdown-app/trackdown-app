import SwiftUI

/// The floating guess bar: a glass search field, a prominent glass Guess button and, while the player types, the
/// glass list of matching stations above them.
///
/// The three pieces sit in one `GlassEffectContainer`, so the list morphs out of the bar when suggestions appear.
/// Place the bar with `safeAreaBar(edge: .bottom)` on the screen's scroll view, so the content scrolls under it with
/// a scroll edge effect instead of a gradient:
///
/// ```swift
/// ScrollView { ... }
///     .trackdownScrollEdges()
///     .safeAreaBar(edge: .bottom) {
///         GuessBar(text: $query, suggestions: suggestions, selection: $selection, onGuess: guess)
///             .padding(.horizontal, 16)
///     }
/// ```
public struct GuessBar: View {
    @Binding private var text: String
    @Binding private var selection: GuessSuggestion.ID?
    private let suggestions: [GuessSuggestion]
    private let onGuess: () -> Void

    @Namespace private var glass
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 56
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At accessibility text sizes the field and the button each get the full width, one above the other: side by side
    /// the field has no room left for what the player types and "Guess" breaks over two lines.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }
    private static let stackedMinHeight: CGFloat = 56

    private var barLayout: AnyLayout {
        isStacked ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
    }

    /// - Parameters:
    ///   - text: What the player has typed.
    ///   - suggestions: The matches for `text`, best first. The list is hidden while this is empty.
    ///   - selection: The highlighted suggestion.
    ///   - onGuess: Guesses the selected suggestion, or what was typed. Called from the button and from the keyboard's
    ///     return key whenever something is typed, so the screen can refuse an unknown or already guessed station with
    ///     a message instead of the button silently doing nothing.
    public init(
        text: Binding<String>,
        suggestions: [GuessSuggestion],
        selection: Binding<GuessSuggestion.ID?>,
        onGuess: @escaping () -> Void
    ) {
        self._text = text
        self._selection = selection
        self.suggestions = suggestions
        self.onGuess = onGuess
    }

    private var canGuess: Bool {
        suggestions.contains { $0.id == selection && !$0.isDisabled }
            || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                if !suggestions.isEmpty {
                    SuggestionList(suggestions: suggestions, selection: $selection)
                        .glassEffect(.regular, in: ConcentricRectangle(corners: .concentric(minimum: .fixed(26))))
                        .glassEffectID("suggestions", in: glass)
                }
                barLayout {
                    field
                    guessButton
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(.smooth, value: suggestions.isEmpty)
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(TrackdownColor.muted)
                .accessibilityHidden(true)
            TextField(text: $text, prompt: Text("Guess a station", bundle: .module)) {
                Text("Guess a station", bundle: .module)
            }
            .font(TrackdownFont.input)
            .foregroundStyle(TrackdownColor.ink)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .onSubmit { if canGuess { onGuess() } }
            .onKeyPress(.downArrow) { moveSelection(by: 1) }
            .onKeyPress(.upArrow) { moveSelection(by: -1) }
        }
        .padding(.horizontal, 18)
        // Stacked, the field has the full width and only needs to be as tall as its text: the scaled height would
        // take a quarter of a small screen.
        .padding(.vertical, isStacked ? 12 : 0)
        .frame(minHeight: isStacked ? Self.stackedMinHeight : height, maxHeight: .infinity)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("field", in: glass)
    }

    private var guessButton: some View {
        Button(action: onGuess) {
            Text("Guess", bundle: .module)
                .font(TrackdownFont.headline)
                .padding(.horizontal, 6)
                .frame(maxWidth: isStacked ? .infinity : nil, maxHeight: .infinity)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(TrackdownColor.ink)
        .foregroundStyle(TrackdownColor.background)
        .disabled(!canGuess)
    }

    private func moveSelection(by offset: Int) -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }
        selection = suggestions.selection(movingFrom: selection, by: offset)
        return .handled
    }
}

/// The glass list of matching stations. The glass itself comes from ``GuessBar``.
struct SuggestionList: View {
    let suggestions: [GuessSuggestion]
    @Binding var selection: GuessSuggestion.ID?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                SuggestionRow(suggestion: suggestion, isSelected: suggestion.id == selection) {
                    selection = suggestion.id
                }
            }
        }
        .padding(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Matching stations", bundle: .module))
    }
}

private struct SuggestionRow: View {
    let suggestion: GuessSuggestion
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 50

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(suggestion.attributedName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let detail = suggestion.detail {
                    Text(verbatim: detail)
                        .font(TrackdownFont.footnote)
                        .foregroundStyle(TrackdownColor.muted)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .contentShape(.rect(cornerRadius: 18))
            .background {
                if isSelected {
                    // A highlight on the row, not glass: rows are content inside the list's glass.
                    RoundedRectangle(cornerRadius: 18)
                        .fill(TrackdownColor.ink.opacity(contrast == .increased ? 0.16 : 0.08))
                } else {
                    EmptyView()
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(TrackdownColor.ink)
        .disabled(suggestion.isDisabled)
        .opacity(suggestion.isDisabled ? 0.5 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(suggestion.isDisabled ? Text("Already guessed", bundle: .module) : Text(verbatim: ""))
    }
}

private struct GuessBarPreview: View {
    @State private var text = "Ams"
    @State private var selection: GuessSuggestion.ID? = "asd"

    private var suggestions: [GuessSuggestion] {
        let all = [
            ("asd", "Amsterdam Centraal"),
            ("asdz", "Amsterdam Zuid"),
            ("ass", "Amsterdam Sloterdijk"),
        ]
        guard !text.isEmpty else { return [] }
        return all.compactMap { id, name in
            guard let range = name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) else {
                return nil
            }
            return GuessSuggestion(
                id: id, name: name, matchedRange: range, detail: "Noord-Holland", isDisabled: id == "ass")
        }
    }

    var body: some View {
        GlassPreviewBackdrop(alignment: .bottom) {
            GuessBar(text: $text, suggestions: suggestions, selection: $selection) {}
                .padding(.horizontal, 16)
        }
    }
}

#Preview("Guess bar") {
    GuessBarPreview()
}

#Preview("Guess bar, dark") {
    GuessBarPreview()
        .preferredColorScheme(.dark)
}
