import SwiftUI

/// Reserved rectangles in the local coordinate space of the safe-content container.
/// Layouts can inspect inactive folds without treating them as obstacles.
public struct TrackdownReservedRegions: Equatable, Sendable {
    public var folds: [CGRect] = []
    public var cameras: [CGRect] = []
}

/// How an active fold divides a screen that spreads its content over both sides, as in the book and tabletop poses of
/// iPhone Duo.
///
/// The sides are in the layout coordinates of the content that ``SwiftUICore/View/reservedContent(spreadsAcrossFold:)``
/// wraps, which fills the container: x runs from the leading edge, so in right-to-left layouts the leading side is on
/// the right. Each side already keeps clear of the fold's margins and of camera regions.
public struct TrackdownFoldSplit: Equatable, Sendable {
    public enum Axis: Equatable, Sendable {
        /// A vertical fold, the book pose: ``TrackdownFoldSplit/first`` is the leading side, ``TrackdownFoldSplit/second``
        /// the trailing side.
        case vertical
        /// A horizontal fold, the tabletop pose: ``TrackdownFoldSplit/first`` is the top half, propped up,
        /// ``TrackdownFoldSplit/second`` the bottom half, flat on the table.
        case horizontal
    }

    public var axis: Axis
    /// The leading or top side.
    public var first: CGRect
    /// The trailing or bottom side.
    public var second: CGRect

    public init(axis: Axis, first: CGRect, second: CGRect) {
        self.axis = axis
        self.first = first
        self.second = second
    }
}

/// An active fold as seen from a view: where it starts and ends along the axis it divides, with its margins, measured
/// from the leading or top edge of the view's full extent, its safe area included.
public struct TrackdownFold: Equatable, Sendable {
    public var axis: TrackdownFoldSplit.Axis
    /// The fold and its margins: x positions for a vertical fold, y positions for a horizontal one.
    public var span: ClosedRange<CGFloat>
}

extension EnvironmentValues {
    @Entry public var trackdownReservedRegions = TrackdownReservedRegions()
    /// The fold dividing a screen that asked to spread across it, or `nil` when the content is one group, displaced
    /// clear of any active region.
    @Entry public var trackdownFoldSplit: TrackdownFoldSplit?
}

extension View {
    /// Keeps the content clear of active fold and camera regions without replacing its state owners.
    /// System navigation remains outside this container and handles its own reserved regions.
    ///
    /// By default the content is displaced into the largest unobstructed rectangle. With `spreadsAcrossFold`, when an
    /// active fold divides the container into two usable sides, the content instead fills the container and reads the
    /// sides from `trackdownFoldSplit`; it is then responsible for keeping everything off the fold. Either way the
    /// content stays the same view, so switching poses keeps its state, focus and scroll position.
    public func reservedContent(spreadsAcrossFold: Bool = false) -> some View {
        modifier(ReservedContent(spreadsAcrossFold: spreadsAcrossFold))
    }

    /// Calls `action` with the active fold, or `nil` when there is none, whenever it moves relative to this view.
    ///
    /// For sizing system containers around a fold, such as a split view's sidebar column.
    public func onFoldChange(_ action: @escaping (TrackdownFold?) -> Void) -> some View {
        onGeometryChange(for: TrackdownFold?.self, of: ReservedRegionQuery.fold(in:), action: action)
    }
}

private struct ReservedContent: ViewModifier {
    let spreadsAcrossFold: Bool

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let regions = ReservedRegionQuery.regions(in: geometry)
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let split =
                spreadsAcrossFold
                ? ReservedContentGeometry.split(in: bounds, folds: regions.activeFolds, avoiding: regions.activeCameras)
                : nil
            let frame =
                split == nil
                ? ReservedContentGeometry.availableFrame(
                    in: bounds, avoiding: regions.activeFolds + regions.activeCameras)
                : bounds
            let outsets = ReservedContentGeometry.clipOutsets(
                frame: frame, bounds: bounds, safeArea: geometry.safeAreaInsets)
            // One code path for both cases, so a pose change never replaces the content.
            content
                .environment(\.trackdownReservedRegions, regions.exposed)
                .environment(\.trackdownFoldSplit, split)
                .frame(width: frame.width, height: frame.height)
                .clipShape(OutsetRectangle(outsets: outsets))
                .contentShape(.rect)
                .position(x: frame.midX, y: frame.midY)
        }
    }
}

/// A rectangle grown past its frame by `outsets`. Leading and trailing follow the layout direction, as the frames and
/// safe area ``ReservedContent`` reads do.
private struct OutsetRectangle: Shape {
    var outsets: EdgeInsets

    var layoutDirectionBehavior: LayoutDirectionBehavior { .mirrors }

    func path(in rect: CGRect) -> Path {
        Path(
            CGRect(
                x: rect.minX - outsets.leading,
                y: rect.minY - outsets.top,
                width: rect.width + outsets.leading + outsets.trailing,
                height: rect.height + outsets.top + outsets.bottom))
    }
}

/// Reads the reserved regions from a geometry proxy, in its layout coordinates (mirrored in right-to-left layouts, like
/// every other SwiftUI frame).
private enum ReservedRegionQuery {
    struct Regions {
        var exposed = TrackdownReservedRegions()
        /// Active folds, expanded by their margins.
        var activeFolds: [CGRect] = []
        /// Active camera regions, expanded by their margins.
        var activeCameras: [CGRect] = []
    }

    static func regions(in geometry: GeometryProxy) -> Regions {
        // The macOS target only supports host tests. Xcode 27.1 ships a macOS 27.0 SDK without this API.
        #if os(iOS)
            if #available(iOS 27.1, *) {
                let folds = geometry.reservedRegions(kind: .division, options: .includeInactive)
                let cameras = geometry.reservedRegions(kind: .occlusion, options: .includeInactive)
                return Regions(
                    exposed: TrackdownReservedRegions(folds: folds.map(\.frame), cameras: cameras.map(\.frame)),
                    activeFolds: folds.filter(\.isActive).map(expandedFrame),
                    activeCameras: cameras.filter(\.isActive).map(expandedFrame))
            }
        #endif
        return Regions()
    }

    static func fold(in geometry: GeometryProxy) -> TrackdownFold? {
        let bounds = CGRect(origin: .zero, size: geometry.size)
        guard let fold = regions(in: geometry).activeFolds.first,
            let axis = ReservedContentGeometry.axis(of: fold, in: bounds)
        else { return nil }
        let insets = geometry.safeAreaInsets
        switch axis {
        case .vertical:
            return TrackdownFold(axis: axis, span: (fold.minX + insets.leading)...(fold.maxX + insets.leading))
        case .horizontal:
            return TrackdownFold(axis: axis, span: (fold.minY + insets.top)...(fold.maxY + insets.top))
        }
    }

    #if os(iOS)
        @available(iOS 27.1, *)
        private static func expandedFrame(_ region: ReservedRegion) -> CGRect {
            let frame = region.frame
            let margins = region.margins
            return CGRect(
                x: frame.minX - margins.leading,
                y: frame.minY - margins.top,
                width: frame.width + margins.leading + margins.trailing,
                height: frame.height + margins.top + margins.bottom)
        }
    #endif
}

/// Keeps controls together on the largest usable side of an active region. No device sizes or pose assumptions.
enum ReservedContentGeometry {
    /// A side narrower than this share of the other is too small to hold part of a screen; the content then stays
    /// together on the larger side.
    static let minimumSideRatio: CGFloat = 1 / 3

    /// The two sides of the one active fold, each clear of `obstacles`, or `nil` when there is no fold, more than one,
    /// or one side is too small to use.
    static func split(in bounds: CGRect, folds: [CGRect], avoiding obstacles: [CGRect]) -> TrackdownFoldSplit? {
        guard folds.count == 1, let fold = folds.first, let axis = axis(of: fold, in: bounds) else { return nil }
        let first: CGRect
        let second: CGRect
        let firstLength: CGFloat
        let secondLength: CGFloat
        switch axis {
        case .vertical:
            first = CGRect(x: bounds.minX, y: bounds.minY, width: fold.minX - bounds.minX, height: bounds.height)
            second = CGRect(x: fold.maxX, y: bounds.minY, width: bounds.maxX - fold.maxX, height: bounds.height)
            firstLength = first.width
            secondLength = second.width
        case .horizontal:
            first = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: fold.minY - bounds.minY)
            second = CGRect(x: bounds.minX, y: fold.maxY, width: bounds.width, height: bounds.maxY - fold.maxY)
            firstLength = first.height
            secondLength = second.height
        }
        guard min(firstLength, secondLength) >= max(firstLength, secondLength) * minimumSideRatio else { return nil }
        let firstFrame = availableFrame(in: first, avoiding: obstacles)
        let secondFrame = availableFrame(in: second, avoiding: obstacles)
        guard !firstFrame.isEmpty, !secondFrame.isEmpty else { return nil }
        return TrackdownFoldSplit(axis: axis, first: firstFrame, second: secondFrame)
    }

    /// Whether `fold` divides `bounds` side by side (vertical) or top and bottom (horizontal); `nil` when it crosses
    /// neither fully.
    static func axis(of fold: CGRect, in bounds: CGRect) -> TrackdownFoldSplit.Axis? {
        let crossesVertically = fold.minY <= bounds.minY && fold.maxY >= bounds.maxY
        let crossesHorizontally = fold.minX <= bounds.minX && fold.maxX >= bounds.maxX
        if crossesVertically && !crossesHorizontally && fold.minX < bounds.maxX && fold.maxX > bounds.minX {
            return .vertical
        }
        if crossesHorizontally && !crossesVertically && fold.minY < bounds.maxY && fold.maxY > bounds.minY {
            return .horizontal
        }
        return nil
    }

    /// How far past `frame` the content may draw. On each edge `frame` shares with `bounds`, that's the container's safe
    /// area there, so a scroll view reaching the edge still runs under the bars and the home indicator. On an edge moved
    /// in to clear a fold or camera, nothing, so the content never draws over the region it avoids.
    static func clipOutsets(frame: CGRect, bounds: CGRect, safeArea: EdgeInsets) -> EdgeInsets {
        func touches(_ edge: CGFloat, _ boundsEdge: CGFloat) -> Bool { abs(edge - boundsEdge) < 0.5 }
        return EdgeInsets(
            top: touches(frame.minY, bounds.minY) ? safeArea.top : 0,
            leading: touches(frame.minX, bounds.minX) ? safeArea.leading : 0,
            bottom: touches(frame.maxY, bounds.maxY) ? safeArea.bottom : 0,
            trailing: touches(frame.maxX, bounds.maxX) ? safeArea.trailing : 0)
    }

    static func availableFrame(in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGRect {
        var candidates = [bounds]
        for obstacle in obstacles {
            candidates = candidates.flatMap { frame -> [CGRect] in
                let intersection = frame.intersection(obstacle)
                guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return [frame] }
                return [
                    CGRect(x: frame.minX, y: frame.minY, width: intersection.minX - frame.minX, height: frame.height),
                    CGRect(
                        x: intersection.maxX, y: frame.minY, width: frame.maxX - intersection.maxX, height: frame.height
                    ),
                    CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: intersection.minY - frame.minY),
                    CGRect(
                        x: frame.minX, y: intersection.maxY, width: frame.width, height: frame.maxY - intersection.maxY),
                ].filter { $0.width > 0 && $0.height > 0 }
            }
        }
        return candidates.max {
            let firstArea = $0.width * $0.height
            let secondArea = $1.width * $1.height
            if firstArea != secondArea { return firstArea < secondArea }
            // Prefer the lower/right region on a tie, keeping controls reachable when propped or held like a book.
            if $0.midY != $1.midY { return $0.midY < $1.midY }
            return $0.midX < $1.midX
        } ?? .zero
    }
}
