import DesignSystem
import GameCore
import SwiftUI

/// The archive as the sidebar of a `NavigationSplitView`, for a display wide enough to show it beside the puzzle, such
/// as the iPhone Duo inner display. Every past puzzle of the network, grouped by month, newest first, with the puzzle
/// open in the detail column highlighted.
///
/// Unlike ``ArchiveView``, every row opens its puzzle beside the list, finished ones too: their revealed game shows
/// with its results a tap away.
public struct ArchiveSidebar: View {
    private let model: ArchiveModel
    private let selection: Int?
    private let onSelect: (ArchiveRow) -> Void
    private let onHide: () -> Void
    @State private var scrollPosition = ScrollPosition(edge: .top)

    /// - Parameters:
    ///   - model: The puzzles to list.
    ///   - selection: The number of the past puzzle open in the detail column, or `nil` for today's.
    ///   - onSelect: Opens the row's puzzle in the detail column.
    ///   - onHide: Hides the sidebar, from its Hide sidebar button.
    public init(
        model: ArchiveModel,
        selection: Int?,
        onSelect: @escaping (ArchiveRow) -> Void,
        onHide: @escaping () -> Void
    ) {
        self.model = model
        self.selection = selection
        self.onSelect = onSelect
        self.onHide = onHide
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A card floating on the page, its corners following the display's.
            .background { card.fill(TrackdownColor.surface) }
            .clipShape(card)
            .padding(8)
            // Down to the bottom of the display, as the column beside it.
            .ignoresSafeArea(.container, edges: .bottom)
            .background { TrackdownColor.background.ignoresSafeArea() }
            .task { await model.load() }
    }

    private var card: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(28)))
    }

    @ViewBuilder
    private var content: some View {
        switch model.entries {
        case .loading:
            VStack(alignment: .leading, spacing: 0) {
                header
                ProgressView {
                    Text("Loading archive", bundle: .module, comment: "Shown while the list of past puzzles loads.")
                }
                .foregroundStyle(TrackdownColor.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 10)
        case .failed(let problem):
            VStack(alignment: .leading, spacing: 0) {
                header
                ProblemView(problem: problem, subject: .archive) {
                    Task { await model.load() }
                }
            }
            .padding(.horizontal, 10)
        case .loaded:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    header
                    ForEach(model.months) { month in
                        SidebarMonth(month: month, selection: selection, onSelect: onSelect)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
            .trackdownScrollEdges()
            .scrollPosition($scrollPosition)
        }
    }

    /// "Archive" and the network, beside the Hide sidebar button.
    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                TrackdownIcon.archive.title
                    .font(TrackdownFont.title)
                    .foregroundStyle(TrackdownColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    "Every past \(model.network.name) station", bundle: .module,
                    comment: "Under the Archive title in the sidebar. The argument is a network, such as Netherlands."
                )
                .font(TrackdownFont.footnote)
                .foregroundStyle(TrackdownColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onHide) {
                Label {
                    Text("Hide sidebar", bundle: .module, comment: "Button that hides the Archive sidebar.")
                } icon: {
                    Image(systemName: "sidebar.leading")
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(TrackdownColor.ink)
        }
        .padding(.leading, 10)
        .padding(.top, 10)
    }
}

/// "November 2026" over the month's rows, without a card: the sidebar is the surface.
private struct SidebarMonth: View {
    let month: ArchiveMonth
    let selection: Int?
    let onSelect: (ArchiveRow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: month.rows.first?.puzzle.date.monthTitle() ?? "")
                .font(TrackdownFont.captionEmphasized)
                .foregroundStyle(TrackdownColor.muted)
                .padding(.horizontal, 10)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            ForEach(month.rows) { row in
                ArchiveRowView(row: row, style: .sidebar(isSelected: isSelected(row))) { onSelect(row) }
            }
        }
    }

    private func isSelected(_ row: ArchiveRow) -> Bool {
        if let selection { row.puzzle.number == selection } else { row.isToday }
    }
}
