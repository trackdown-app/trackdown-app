import SwiftUI

/// Reserved rectangles in the local coordinate space of the safe-content container.
/// Layouts can inspect inactive folds without treating them as obstacles.
public struct TrackdownReservedRegions: Equatable, Sendable {
    public var folds: [CGRect] = []
    public var cameras: [CGRect] = []
}

extension EnvironmentValues {
    @Entry public var trackdownReservedRegions = TrackdownReservedRegions()
}

extension View {
    /// Displaces the existing content into one unobstructed region without replacing its state owners.
    /// System navigation remains outside this container and handles its own reserved regions.
    public func reservedContent() -> some View {
        modifier(ReservedContent())
    }
}

private struct ReservedContent: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let regions = regions(in: geometry)
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let frame = ReservedContentGeometry.availableFrame(in: bounds, avoiding: regions.obstacles)
            content
                .environment(\.trackdownReservedRegions, regions.exposed)
                .frame(width: frame.width, height: frame.height)
                .clipped()
                .contentShape(.rect)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    private func regions(in geometry: GeometryProxy) -> (exposed: TrackdownReservedRegions, obstacles: [CGRect]) {
        // The macOS target only supports host tests. Xcode 27.1 ships a macOS 27.0 SDK without this API.
        #if os(iOS)
            if #available(iOS 27.1, *) {
                let folds = geometry.reservedRegions(
                    kind: .division, options: .includeInactive, layoutDirectionBehavior: .fixed)
                let cameras = geometry.reservedRegions(
                    kind: .occlusion, options: .includeInactive, layoutDirectionBehavior: .fixed)
                let obstacles = (folds + cameras).filter(\.isActive).map { region in
                    let frame = region.frame
                    let margins = region.margins
                    return CGRect(
                        x: frame.minX - (layoutDirection == .rightToLeft ? margins.trailing : margins.leading),
                        y: frame.minY - margins.top,
                        width: frame.width + margins.leading + margins.trailing,
                        height: frame.height + margins.top + margins.bottom)
                }
                return (
                    TrackdownReservedRegions(folds: folds.map(\.frame), cameras: cameras.map(\.frame)), obstacles
                )
            }
        #endif
        return (TrackdownReservedRegions(), [])
    }
}

/// Keeps controls together on the largest usable side of an active region. No device sizes or pose assumptions.
enum ReservedContentGeometry {
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
