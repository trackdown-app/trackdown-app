import Foundation
import SwiftUI

/// One row of the suggestion list above the guess bar.
///
/// `DesignSystem` does not know about stations; the screen maps each search match to a suggestion.
public struct GuessSuggestion: Identifiable, Hashable, Sendable {
    public var id: String
    /// The name shown in the row, such as `Amsterdam Centraal`.
    public var name: String
    /// The part of ``name`` that matched what the player typed. It is drawn bold.
    public var matchedRange: Range<String.Index>?
    /// Secondary text on the trailing side, such as the province.
    public var detail: String?
    /// Whether the row can not be picked, for example because the station was already guessed.
    public var isDisabled: Bool

    public init(
        id: String,
        name: String,
        matchedRange: Range<String.Index>? = nil,
        detail: String? = nil,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.matchedRange = matchedRange
        self.detail = detail
        self.isDisabled = isDisabled
    }

    /// ``name`` in the body font with the matched part in the emphasized font.
    var attributedName: AttributedString {
        var result = AttributedString(name)
        result.font = TrackdownFont.body
        if let matchedRange, let range = Range(matchedRange, in: result) {
            result[range].font = TrackdownFont.headline
        }
        return result
    }
}

extension [GuessSuggestion] {
    /// The suggestion `offset` rows away from `selection`, skipping disabled rows, for arrow-key navigation.
    ///
    /// With no selection, moving down picks the first enabled row and moving up the last. At either end the selection
    /// stays where it is.
    func selection(movingFrom selection: GuessSuggestion.ID?, by offset: Int) -> GuessSuggestion.ID? {
        let enabled = filter { !$0.isDisabled }.map(\.id)
        guard !enabled.isEmpty, offset != 0 else { return selection }
        guard let selection, let index = enabled.firstIndex(of: selection) else {
            return offset > 0 ? enabled.first : enabled.last
        }
        return enabled[Swift.min(Swift.max(index + offset, 0), enabled.count - 1)]
    }
}
