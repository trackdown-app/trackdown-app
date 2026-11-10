import SwiftUI

/// What a subview of ``TripLineLayout`` draws. Subviews without a part are not shown.
enum TripLinePart: Hashable {
    case dot
    case ride(Int)
    /// A candidate label for the ride at that index. The layout shows the longest one that fits.
    case label(ride: Int, fit: TripLineLabelFit)
    case change(Int)
    case bar
}

extension TripLinePart: LayoutValueKey {
    static let defaultValue: TripLinePart? = nil
}

/// Lays out a trip line from ``TripLineGeometry``, and shows each ride's longest label that fits.
///
/// Every ride may get a `.full` and a `.short` label subview. Both are measured at their ideal size;
/// the one that fits inside the visible part of its segment is placed at the segment's center, the
/// other is placed with a zero size. Label subviews must therefore draw nothing at a zero size (see
/// `TripLine`, which clips them).
struct TripLineLayout: Layout {
    var pieces: [TripLinePiece]
    var metrics: TripLineMetrics

    /// Takes the width the parent proposes. With none, such as inside a horizontal scroll view, it takes the narrowest
    /// width at which every ride shows its full label.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width =
            proposal.width
            ?? TripLineGeometry.idealWidth(
                pieces: pieces, fullLabelWidths: fullLabelWidths(subviews: subviews), metrics: metrics)
        return CGSize(width: width, height: metrics.height)
    }

    /// The ideal width of each ride's full label, by ride index.
    private func fullLabelWidths(subviews: Subviews) -> [CGFloat] {
        var widths: [Int: CGFloat] = [:]
        for subview in subviews {
            guard case .label(let index, .full) = subview[TripLinePart.self] else { continue }
            widths[index] = subview.sizeThatFits(.unspecified).width
        }
        let rideCount = pieces.filter { if case .ride = $0 { true } else { false } }.count
        return (0..<rideCount).map { widths[$0] ?? 0 }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let geometry = TripLineGeometry(pieces: pieces, width: bounds.width, metrics: metrics)
        let fits = labelFits(subviews: subviews, geometry: geometry)

        func place(_ subview: LayoutSubview, in rect: CGRect) {
            subview.place(
                at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(rect.size)
            )
        }

        for subview in subviews {
            switch subview[TripLinePart.self] {
            case .dot:
                place(subview, in: geometry.dot)
            case .ride(let index) where geometry.rides.indices.contains(index):
                place(subview, in: geometry.rides[index].frame)
            case .change(let index) where geometry.changes.indices.contains(index):
                place(subview, in: geometry.changes[index])
            case .bar:
                place(subview, in: geometry.bar)
            case .label(let index, let fit) where geometry.rides.indices.contains(index) && fits[index] == fit:
                let visible = geometry.rides[index].visible
                subview.place(
                    at: CGPoint(x: bounds.minX + visible.midX, y: bounds.minY + visible.midY),
                    anchor: .center,
                    proposal: .unspecified
                )
            default:
                subview.place(at: bounds.origin, anchor: .topLeading, proposal: .zero)
            }
        }
    }

    /// The label each ride shows, by ride index.
    private func labelFits(subviews: Subviews, geometry: TripLineGeometry) -> [TripLineLabelFit] {
        var full = Array(repeating: CGFloat.infinity, count: geometry.rides.count)
        var short = full
        for subview in subviews {
            guard case .label(let index, let fit) = subview[TripLinePart.self], full.indices.contains(index)
            else { continue }
            let width = subview.sizeThatFits(.unspecified).width
            switch fit {
            case .full: full[index] = width
            case .short: short[index] = width
            case .none: break
            }
        }
        return geometry.rides.indices.map { index in
            TripLineLabelFit.choose(
                full: full[index],
                short: short[index],
                available: geometry.rides[index].visible.width,
                padding: metrics.labelPadding
            )
        }
    }
}
