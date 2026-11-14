import CoreGraphics

/// The sizes ``TripLine`` draws with, in points. ``TripLine`` scales them with Dynamic Type.
struct TripLineMetrics: Sendable, Hashable {
    /// Height of a ride segment, and the diameter of the guess dot.
    var lineHeight: CGFloat = 20
    /// How far a ride segment runs under the guess dot.
    var dotOverlap: CGFloat = 4
    /// Diameter of a change ring.
    var ringDiameter: CGFloat = 28
    /// How far a ride segment runs under a change ring, on each side. Past where the ring's curve crosses the segment's
    /// edges (about 4.2 points in), so no corner of the segment shows beside the ring.
    var ringOverlap: CGFloat = 6
    /// Stroke of the change rings and the mystery-station bar.
    var strokeWidth: CGFloat = 4
    /// Width and height of the mystery-station bar.
    var barWidth: CGFloat = 24
    var barHeight: CGFloat = 44
    /// Room a label keeps free on each side inside its segment.
    var labelPadding: CGFloat = 4
    /// The least of a ride segment that shows between the dot, rings and bar, so a short ride still reads as a piece
    /// of line rather than slivers peeking out around a ring.
    var minimumVisibleRide: CGFloat = 10

    /// Scales every size by `factor`, as `@ScaledMetric` does for Dynamic Type.
    func scaled(by factor: CGFloat) -> TripLineMetrics {
        TripLineMetrics(
            lineHeight: lineHeight * factor,
            dotOverlap: dotOverlap * factor,
            ringDiameter: ringDiameter * factor,
            ringOverlap: ringOverlap * factor,
            strokeWidth: strokeWidth * factor,
            barWidth: barWidth * factor,
            barHeight: barHeight * factor,
            labelPadding: labelPadding * factor,
            minimumVisibleRide: minimumVisibleRide * factor
        )
    }

    /// Height of the whole line: the tallest part.
    var height: CGFloat { max(lineHeight, ringDiameter, barHeight) }
}

/// One piece of a trip as the line draws it.
enum TripLinePiece: Sendable, Hashable {
    /// A ride segment, as wide as its share of the riding time.
    case ride(minutes: Int)
    /// A change ring, always the same width.
    case change(minutes: Int)

    var minutes: Int {
        switch self {
        case .ride(let minutes), .change(let minutes): minutes
        }
    }
}

/// Which label a ride segment shows.
enum TripLineLabelFit: Sendable, Hashable {
    /// Train and time: `IC 2h 02m`.
    case full
    /// Time only: `2h 02m`.
    case short
    /// The segment is too narrow for either.
    case none

    /// The longest label that fits in `available` points with `padding` free on each side.
    static func choose(full: CGFloat, short: CGFloat, available: CGFloat, padding: CGFloat) -> TripLineLabelFit {
        let room = available - 2 * padding
        if full <= room { return .full }
        if short <= room { return .short }
        return .none
    }
}

/// Where every part of a trip line goes, for a given width. Pure math, so it is unit tested.
///
/// The line is right-aligned so every trip ends at the mystery-station bar, whose center sits on the
/// line's end. Its length is the trip's share of ``fullTrackMinutes`` (at least ``minimumFraction``
/// of the track). The guess dot and change rings keep their size; the ride segments share what is left
/// in proportion to their minutes, with a short ride kept wide enough to show (see ``rideWidths(pieces:available:metrics:)``).
struct TripLineGeometry: Sendable, Hashable {
    /// A trip this long fills the whole track.
    static let fullTrackMinutes = 150
    /// The shortest line, as a fraction of the track, so even a one-stop trip stays visible.
    static let minimumFraction = 0.14

    struct Ride: Sendable, Hashable {
        /// The segment, including the parts under the dot, rings and bar.
        var frame: CGRect
        /// The part of the segment nothing covers: where a label can go.
        var visible: CGRect
    }

    var dot: CGRect
    var rides: [Ride]
    var changes: [CGRect]
    var bar: CGRect

    /// The line's length as a fraction of the track: `totalMinutes / 150`, clamped to 14 %...100 %.
    static func lineFraction(totalMinutes: Int) -> Double {
        let fraction = Double(totalMinutes) / Double(fullTrackMinutes)
        return min(1, max(minimumFraction, fraction))
    }

    /// The narrowest width at which every ride has room for its full label, for when the parent proposes no width,
    /// such as inside a horizontal scroll view. Every screen proposes its own width instead, so lines of different
    /// trips stay comparable.
    ///
    /// - Parameter fullLabelWidths: The width of each ride's full label, by ride index.
    static func idealWidth(pieces: [TripLinePiece], fullLabelWidths: [CGFloat], metrics: TripLineMetrics) -> CGFloat {
        let rideMinutes = pieces.compactMap { piece -> Int? in
            if case .ride(let minutes) = piece { return minutes }
            return nil
        }
        let changeCount = pieces.count - rideMinutes.count
        let rideSum = rideMinutes.reduce(0, +)

        // Each ride needs its label and padding, plus what the dot, a ring or the bar covers at either end.
        var rideWidth: CGFloat = 0
        for (rideIndex, covered) in coveredWidths(pieces: pieces, metrics: metrics).enumerated() {
            let minutes = rideMinutes[rideIndex]
            let label = fullLabelWidths.indices.contains(rideIndex) ? fullLabelWidths[rideIndex] : 0
            let needed = label + 2 * metrics.labelPadding + covered
            // A ride gets its share of the riding time, so the total must make this ride's share large enough.
            let total =
                rideSum > 0
                ? needed * CGFloat(rideSum) / CGFloat(max(1, minutes))
                : needed * CGFloat(rideMinutes.count)
            rideWidth = max(rideWidth, total)
        }

        let dotAdvance = metrics.lineHeight - metrics.dotOverlap
        let ringAdvance = metrics.ringDiameter - 2 * metrics.ringOverlap
        let lineWidth = rideWidth + dotAdvance + CGFloat(changeCount) * ringAdvance
        let trackWidth = lineWidth / lineFraction(totalMinutes: pieces.reduce(0) { $0 + $1.minutes })
        return (trackWidth + metrics.barWidth / 2).rounded(.up)
    }

    /// How much of each ride segment the dot, a ring or the bar covers at its two ends, by ride index.
    static func coveredWidths(pieces: [TripLinePiece], metrics: TripLineMetrics) -> [CGFloat] {
        pieces.indices.compactMap { index -> CGFloat? in
            guard case .ride = pieces[index] else { return nil }
            let before: TripLinePiece? = index > 0 ? pieces[index - 1] : nil
            let after: TripLinePiece? = pieces.indices.contains(index + 1) ? pieces[index + 1] : nil
            let leading: CGFloat =
                switch before {
                case nil: metrics.dotOverlap
                case .change: metrics.ringOverlap
                case .ride: 0
                }
            let trailing: CGFloat =
                switch after {
                case nil: metrics.barWidth / 2
                case .change: metrics.ringOverlap
                case .ride: 0
                }
            return leading + trailing
        }
    }

    /// Shares `available` points between the rides in proportion to their minutes, except that no ride gets less than
    /// what its ends cover plus ``TripLineMetrics/minimumVisibleRide``. A ride held at that minimum leaves the rest to
    /// the others, still in proportion. When even the minimums do not fit, each ride gets its minimum scaled down.
    static func rideWidths(pieces: [TripLinePiece], available: CGFloat, metrics: TripLineMetrics) -> [CGFloat] {
        let minutes = pieces.compactMap { piece -> Int? in
            if case .ride(let minutes) = piece { return minutes }
            return nil
        }
        let minimums = coveredWidths(pieces: pieces, metrics: metrics).map { $0 + metrics.minimumVisibleRide }
        let minimumSum = minimums.reduce(0, +)
        guard minimumSum < available else {
            return minimums.map { minimumSum > 0 ? $0 * available / minimumSum : 0 }
        }

        var held = Set<Int>()
        while true {
            let free = minutes.indices.filter { !held.contains($0) }
            let room = available - held.reduce(0) { $0 + minimums[$1] }
            let freeMinutes = free.reduce(0) { $0 + minutes[$1] }
            func share(_ index: Int) -> CGFloat {
                freeMinutes > 0
                    ? room * CGFloat(minutes[index]) / CGFloat(freeMinutes)
                    : room / CGFloat(free.count)
            }
            let tooNarrow = free.filter { share($0) < minimums[$0] }
            guard tooNarrow.isEmpty else {
                held.formUnion(tooNarrow)
                continue
            }
            return minutes.indices.map { held.contains($0) ? minimums[$0] : share($0) }
        }
    }

    init(pieces: [TripLinePiece], width: CGFloat, metrics: TripLineMetrics) {
        let midY = metrics.height / 2
        let trackWidth = max(0, width - metrics.barWidth / 2)
        let totalMinutes = pieces.reduce(0) { $0 + $1.minutes }
        let changeCount = pieces.count { if case .change = $0 { true } else { false } }

        // The dot and each ring take a fixed width; the rides share the rest. A short trip with several changes grows
        // past its share of the track, up to the whole track, until every ride shows a piece of line.
        let dotAdvance = metrics.lineHeight - metrics.dotOverlap
        let ringAdvance = metrics.ringDiameter - 2 * metrics.ringOverlap
        let fixedWidth = dotAdvance + CGFloat(changeCount) * ringAdvance
        let minimumRides = Self.coveredWidths(pieces: pieces, metrics: metrics)
            .reduce(0) { $0 + $1 + metrics.minimumVisibleRide }
        let lineWidth = min(
            trackWidth, max(trackWidth * Self.lineFraction(totalMinutes: totalMinutes), fixedWidth + minimumRides))
        let start = trackWidth - lineWidth
        let rideWidth = max(0, lineWidth - fixedWidth)
        let rideWidths = Self.rideWidths(pieces: pieces, available: rideWidth, metrics: metrics)

        dot = CGRect(
            x: start, y: midY - metrics.lineHeight / 2, width: metrics.lineHeight, height: metrics.lineHeight)
        bar = CGRect(
            x: width - metrics.barWidth, y: midY - metrics.barHeight / 2,
            width: metrics.barWidth, height: metrics.barHeight)

        var rides: [Ride] = []
        var changes: [CGRect] = []
        var x = dot.maxX - metrics.dotOverlap
        // Where the visible part of the next segment starts: after the dot or the last ring.
        var coveredUntil = dot.maxX
        for (index, piece) in pieces.enumerated() {
            switch piece {
            case .ride:
                let segmentWidth = rideWidths[rides.count]
                let frame = CGRect(
                    x: x, y: midY - metrics.lineHeight / 2, width: segmentWidth, height: metrics.lineHeight)
                // Visible until the next ring, or until the bar for the last segment.
                let coveredFrom: CGFloat =
                    switch pieces.indices.contains(index + 1) ? pieces[index + 1] : nil {
                    case nil: bar.minX
                    case .change: frame.maxX - metrics.ringOverlap
                    case .ride: frame.maxX
                    }
                let visibleStart = max(frame.minX, coveredUntil)
                let visibleEnd = max(visibleStart, min(frame.maxX, coveredFrom))
                let visible = CGRect(
                    x: visibleStart, y: frame.minY, width: visibleEnd - visibleStart, height: frame.height)
                rides.append(Ride(frame: frame, visible: visible))
                x = frame.maxX
                coveredUntil = frame.maxX
            case .change:
                let ring = CGRect(
                    x: x - metrics.ringOverlap, y: midY - metrics.ringDiameter / 2,
                    width: metrics.ringDiameter, height: metrics.ringDiameter)
                changes.append(ring)
                x = ring.maxX - metrics.ringOverlap
                coveredUntil = ring.maxX
            }
        }
        self.rides = rides
        self.changes = changes
    }
}
