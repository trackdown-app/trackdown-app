import DesignSystem
import GameCore
import SwiftUI

/// The Archive screen: every past puzzle of the network, grouped by month, newest first. Unfinished puzzles can be
/// played; finished ones show how they went and open their Solved or Missed sheet.
///
/// Push it onto a `NavigationStack`; the system's glass back button returns to where it was opened from.
public struct ArchiveView: View {
    private let model: ArchiveModel
    private let onSelect: (ArchiveRow.Action) -> Void
    private let onChooseNetwork: () -> Void

    /// - Parameters:
    ///   - model: The puzzles to list.
    ///   - onSelect: Continues today's puzzle, plays a past one, or opens a finished game's results.
    ///   - onChooseNetwork: Opens the network picker, from the network pill.
    public init(
        model: ArchiveModel,
        onSelect: @escaping (ArchiveRow.Action) -> Void,
        onChooseNetwork: @escaping () -> Void
    ) {
        self.model = model
        self.onSelect = onSelect
        self.onChooseNetwork = onChooseNetwork
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { TrackdownColor.background.ignoresSafeArea() }
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    NetworkPill(code: model.network.code, name: model.network.name, action: onChooseNetwork)
                        // The bar proposes an icon-sized width; the pill needs room for the network's name.
                        .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .toolbarTitleDisplayMode(.inline)
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.entries {
        case .loading:
            ProgressView {
                Text("Loading archive", bundle: .module, comment: "Shown while the list of past puzzles loads.")
            }
            .foregroundStyle(TrackdownColor.muted)
        case .failed(let problem):
            ProblemView(problem: problem, subject: .archive) {
                Task { await model.load() }
            }
        case .loaded:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    ForEach(model.months) { month in
                        MonthSection(month: month, onSelect: onSelect)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .readableWidth()
            }
            .trackdownScrollEdges()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TrackdownIcon.archive.title
                .font(TrackdownFont.largeTitle)
                .foregroundStyle(TrackdownColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Every past \(model.network.name) station. Play the ones you missed, or look back at how you did.",
                bundle: .module,
                comment: "Introduction under the Archive title. The argument is a network, such as Netherlands."
            )
            .font(TrackdownFont.callout)
            .foregroundStyle(TrackdownColor.muted)
        }
    }
}

/// "November 2026" over the month's rows on one rounded surface, with a hairline between rows.
private struct MonthSection: View {
    let month: ArchiveMonth
    let onSelect: (ArchiveRow.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: month.rows.first?.puzzle.date.monthTitle() ?? "")
                .font(TrackdownFont.subheadlineEmphasized)
                .foregroundStyle(TrackdownColor.muted)
                .padding(.horizontal, 16)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(month.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(TrackdownColor.rule)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    } else {
                        EmptyView()
                    }
                    ArchiveRowView(row: row) { onSelect(row.action) }
                }
            }
            .background { RoundedRectangle(cornerRadius: 26).fill(TrackdownColor.surface) }
            .clipShape(.rect(cornerRadius: 26))
        }
    }
}

/// One past puzzle: the weekday and day, the station (once finished) with how it went, and Play, Continue or the
/// result.
private struct ArchiveRowView: View {
    let row: ArchiveRow
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var dateWidth: CGFloat = 40
    @ScaledMetric(relativeTo: .subheadline) private var chipHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .title3) private var minHeight: CGFloat = 64

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(verbatim: row.puzzle.date.shortWeekday())
                        .font(TrackdownFont.captionEmphasized)
                        .foregroundStyle(TrackdownColor.muted)
                    Text(row.puzzle.date.day, format: .number)
                        .font(TrackdownFont.title2)
                        .monospacedDigit()
                        .foregroundStyle(TrackdownColor.ink)
                }
                .frame(minWidth: dateWidth)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: row.puzzle.date.title()))

                VStack(alignment: .leading, spacing: 0) {
                    title
                        .font(TrackdownFont.title3)
                        .foregroundStyle(TrackdownColor.ink)
                        .lineLimit(1)
                    subtitle
                        .font(TrackdownFont.footnote)
                        .monospacedDigit()
                        .foregroundStyle(TrackdownColor.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailing
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .frame(minHeight: minHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var title: Text {
        if let station = row.station {
            return Text(verbatim: station)
        }
        switch row.progress {
        case .solved:
            return Text(
                "Tracked down", bundle: .module,
                comment: "Archive row of a solved puzzle while its station's name has not loaded.")
        case .missed:
            return Text(
                "Out of guesses", bundle: .module,
                comment: "Archive row of a missed puzzle while its station's name has not loaded.")
        case .notStarted, .started:
            if row.isToday {
                return Text("Today's station", bundle: .module, comment: "Archive row of today's unfinished puzzle.")
            }
            if row.progress == .notStarted {
                return Text("Not played yet", bundle: .module, comment: "Archive row of a past puzzle never played.")
            }
            return Text(
                "Not finished yet", bundle: .module, comment: "Archive row of a past puzzle started but not finished.")
        }
    }

    private var subtitle: Text {
        let number = row.puzzle.number
        switch row.progress {
        case .notStarted, .missed:
            return Text(
                "Puzzle \(number)", bundle: .module,
                comment: "Under an archive row's station: the puzzle number.")
        case .started(let currentGuess, let maxGuesses):
            return Text(
                "Puzzle \(number), guess \(currentGuess) of \(maxGuesses)", bundle: .module,
                comment: "Under the day on the playing screen: the puzzle number and which guess is being made.")
        case .solved(let guesses, _):
            return Text(
                "Puzzle \(number), solved in \(guesses)", bundle: .module,
                comment: "Under an archive row's station: the puzzle number and how many guesses it took.")
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch row.progress {
        case .solved(let guesses, let maxGuesses):
            Text(
                "\(guesses)/\(maxGuesses)", bundle: .module,
                comment: "Result at the end of an archive row: guesses used of the guesses allowed, such as 4/6."
            )
            .font(TrackdownFont.headline)
            .monospacedDigit()
            .foregroundStyle(TrackdownColor.ink)
            .padding(.trailing, 6)
            .accessibilityLabel(
                Text(
                    "\(guesses) of \(maxGuesses) guesses", bundle: .module,
                    comment: "VoiceOver label of an archive row's result, such as \"4 of 6 guesses\"."))
        case .missed:
            Text("Missed", bundle: .module, comment: "Chart row of the games that ran out of guesses.")
                .font(TrackdownFont.headline)
                .foregroundStyle(TrackdownColor.muted)
                .padding(.trailing, 6)
        case .notStarted, .started:
            Group {
                if row.isToday {
                    Text("Continue", bundle: .module, comment: "Archive row button that goes back to today's puzzle.")
                } else {
                    Text("Play", bundle: .module, comment: "Archive row button that plays a past puzzle.")
                }
            }
            .font(TrackdownFont.subheadlineEmphasized)
            .foregroundStyle(TrackdownColor.background)
            .padding(.horizontal, 16)
            .frame(minHeight: chipHeight)
            .background { Capsule().fill(TrackdownColor.ink) }
        }
    }
}
