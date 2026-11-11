import GameCore
import SwiftUI

/// One guess drawn as the fastest train trip to the mystery station: the clue the game is played with.
///
/// Reads left to right: a black dot for the guessed station, one colored segment per train
/// (``TrackdownColor/line1`` → ``TrackdownColor/line2`` → ``TrackdownColor/line3``), a ring at each
/// change, and the tall mystery-station bar at the end. A ring shows "?" while its station is hidden
/// and is empty once the player has guessed it; the name then appears in the summary.
///
/// The line is as long as the trip (150 minutes fill the track, never shorter than 14 %), and each
/// segment as wide as its share of the riding time. A segment shows "IC 2h 02m", or "2h 02m", or
/// nothing, whichever fits.
///
/// VoiceOver reads the whole row as one element: "Maastricht, 2 hours, 25 minutes, change at a hidden
/// station". The dot's halo takes the environment's `backgroundStyle`, or ``TrackdownColor/background``
/// when none is set; set `.backgroundStyle(TrackdownColor.surface)` when the line sits on a card.
public struct TripLine: View {
    /// Where the station's name goes relative to the track.
    public enum Arrangement: Sendable {
        /// The name, time and summary above the track, which gets the full width.
        case stacked
        /// The name, time and summary in a column beside the track, so each guess takes one short row. For a wide,
        /// short space such as the propped-up half of iPhone Duo in the tabletop pose.
        case besideTrack
    }

    private let station: String
    private let steps: [TripStep]
    private let changeNames: [String?]
    private let arrangement: Arrangement

    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    /// The width of the name column beside the track.
    @ScaledMetric(relativeTo: .title2) private var nameColumnWidth: CGFloat = 200
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The largest text size the track follows.
    static let largestTrackSize = DynamicTypeSize.xxxLarge

    /// - Parameters:
    ///   - station: The guessed station's name.
    ///   - steps: The trip from the guessed station to the mystery station.
    ///   - arrangement: Whether the name goes above the track or beside it.
    ///   - stationName: The display name for a change station's code.
    public init(
        station: String,
        steps: [TripStep],
        arrangement: Arrangement = .stacked,
        stationName: (StationCode) -> String
    ) {
        self.station = station
        self.steps = steps
        self.arrangement = arrangement
        self.changeNames = steps.compactMap { step -> String?? in
            guard case .change(let code, _) = step else { return nil }
            return .some(code.map(stationName))
        }
    }

    private var metrics: TripLineMetrics { TripLineMetrics().scaled(by: scale) }
    private var totalMinutes: Int { steps.reduce(0) { $0 + $1.minutes } }
    private var summary: TripSummary { TripSummary(changeNames: changeNames) }
    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    /// The station and the trip time side by side, or the time under the station at accessibility sizes, where side
    /// by side would break the name into slivers.
    private var headingLayout: AnyLayout {
        isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
    }

    /// Beside the track only while the text fits a column: at accessibility sizes the name needs the full width.
    private var isBesideTrack: Bool { arrangement == .besideTrack && !isAccessibilitySize }

    /// The text above the track, or a column beside it.
    private var rowLayout: AnyLayout {
        isBesideTrack
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 12 * scale))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
    }

    /// Room kept between stacked text and the mystery-station bar below its end. Beside the track the text never
    /// reaches the bar; at accessibility sizes the text needs the full width.
    private var textTrailingPadding: CGFloat {
        isBesideTrack || isAccessibilitySize ? 0 : metrics.barWidth + 12 * scale
    }

    public var body: some View {
        rowLayout {
            VStack(alignment: .leading, spacing: 4) {
                headingLayout {
                    Text(station)
                        .font(TrackdownFont.title2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                    Text(totalMinutes.formatted(.tripDuration))
                        .font(TrackdownFont.time)
                        .accessibilityHidden(true)
                }
                Text(summary.text)
                    .font(TrackdownFont.footnote)
                    .foregroundStyle(TrackdownColor.muted)
                    .accessibilityHidden(true)
            }
            .padding(.trailing, textTrailingPadding)
            .frame(width: isBesideTrack ? nameColumnWidth : nil, alignment: .leading)
            .accessibilityHidden(true)

            TripTrack(pieces: pieces, rides: rides, changeNames: changeNames)
                .accessibilityIdentifier("trip-track")
                // The track is a drawing: past this size its rings and bar would crowd out the rides. The text above
                // keeps growing.
                .dynamicTypeSize(...Self.largestTrackSize)
                .accessibilityHidden(true)
                // The line's first baseline is the station name's, so a guess number beside it lines up with the name.
                // Beside the track the row would otherwise take the baseline of an unused segment label at the top.
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
        }
        .foregroundStyle(TrackdownColor.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }

    private var accessibilityLabel: String {
        String(
            localized: .tripLineAccessibilityLabel(
                station, totalMinutes.formatted(.spokenTripDuration), summary.spokenText))
    }

    private var pieces: [TripLinePiece] {
        steps.map { step in
            switch step {
            case .ride(_, let minutes): .ride(minutes: minutes)
            case .change(_, let minutes): .change(minutes: minutes)
            }
        }
    }

    private var rides: [(train: TrainType, minutes: Int)] {
        steps.compactMap { step in
            guard case .ride(let train, let minutes) = step else { return nil }
            return (train, minutes)
        }
    }
}

/// The drawn line of a ``TripLine``: dot, ride segments with their labels, change rings and the mystery-station bar.
private struct TripTrack: View {
    let pieces: [TripLinePiece]
    let rides: [(train: TrainType, minutes: Int)]
    let changeNames: [String?]

    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    @Environment(\.backgroundStyle) private var backgroundStyle

    private var metrics: TripLineMetrics { TripLineMetrics().scaled(by: scale) }

    var body: some View {
        TripLineLayout(pieces: pieces, metrics: metrics) {
            ForEach(rides.indices, id: \.self) { index in
                Rectangle()
                    .fill(TrackdownColor.lines[min(index, TrackdownColor.lines.count - 1)])
                    .layoutValue(key: TripLinePart.self, value: .ride(index))
            }
            ForEach(rides.indices, id: \.self) { index in
                let ride = rides[index]
                let time = ride.minutes.formatted(.tripDuration)
                SegmentLabel(text: "\(ride.train.rawValue) \(time)")
                    .layoutValue(key: TripLinePart.self, value: .label(ride: index, fit: .full))
                SegmentLabel(text: time)
                    .layoutValue(key: TripLinePart.self, value: .label(ride: index, fit: .short))
            }
            Circle()
                .fill(TrackdownColor.ink)
                .background {
                    Circle()
                        .fill(backgroundStyle ?? AnyShapeStyle(TrackdownColor.background))
                        .padding(-3 * scale)
                }
                .layoutValue(key: TripLinePart.self, value: .dot)
            ForEach(changeNames.indices, id: \.self) { index in
                ChangeRing(hidden: changeNames[index] == nil, strokeWidth: metrics.strokeWidth)
                    .layoutValue(key: TripLinePart.self, value: .change(index))
            }
            Capsule()
                .strokeBorder(TrackdownColor.ink, lineWidth: metrics.strokeWidth)
                .background { Capsule().fill(TrackdownColor.surface) }
                .layoutValue(key: TripLinePart.self, value: .bar)
        }
        .padding(.vertical, 4 * scale)
    }
}

/// A label inside a ride segment. Draws nothing when ``TripLineLayout`` places it at a zero size.
private struct SegmentLabel: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(TrackdownFont.lineLabel)
            .accessibilityHidden(true)
            .accessibilityIdentifier("trip-track")
            .foregroundStyle(TrackdownColor.onLine)
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
    }
}

/// The ring at a change of trains: "?" while the station is hidden, empty once guessed.
private struct ChangeRing: View {
    let hidden: Bool
    let strokeWidth: CGFloat

    var body: some View {
        Circle()
            .strokeBorder(TrackdownColor.ink, lineWidth: strokeWidth)
            .background { Circle().fill(TrackdownColor.surface) }
            .overlay {
                if hidden {
                    Text(verbatim: "?")
                        .font(TrackdownFont.lineLabel)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("trip-track")
                        .foregroundStyle(TrackdownColor.ink)
                } else {
                    EmptyView()
                }
            }
    }
}

// MARK: - Previews

private let previewNames: [StationCode: String] = ["ut": "Utrecht Centraal", "asd": "Amsterdam Centraal"]

#Preview("Direct, one change, two changes") {
    TrackdownFont.register()
    return VStack(spacing: 24) {
        TripLine(station: "Hilversum", steps: [.ride(train: "IC", minutes: 13)]) { previewNames[$0] ?? $0.rawValue }
        TripLine(station: "Utrecht Centraal", steps: [.ride(train: "IC", minutes: 17)]) {
            previewNames[$0] ?? $0.rawValue
        }
        TripLine(
            station: "Maastricht",
            steps: [
                .ride(train: "IC", minutes: 122), .change(station: nil, minutes: 6), .ride(train: "IC", minutes: 17),
            ]
        ) { previewNames[$0] ?? $0.rawValue }
        TripLine(
            station: "Den Helder",
            steps: [
                .ride(train: "IC", minutes: 72), .change(station: "asd", minutes: 9), .ride(train: "IC", minutes: 36),
            ]
        ) { previewNames[$0] ?? $0.rawValue }
        TripLine(
            station: "Vlissingen",
            steps: [
                .ride(train: "IC", minutes: 58), .change(station: nil, minutes: 4),
                .ride(train: "IC", minutes: 41), .change(station: "ut", minutes: 7),
                .ride(train: "SPR", minutes: 22),
            ]
        ) { previewNames[$0] ?? $0.rawValue }
    }
    .padding(16)
    .background { TrackdownColor.background }
}

#Preview("Beside the track", traits: .fixedLayout(width: 669, height: 240)) {
    TrackdownFont.register()
    return VStack(spacing: 16) {
        TripLine(
            station: "Maastricht",
            steps: [
                .ride(train: "IC", minutes: 122), .change(station: nil, minutes: 6), .ride(train: "IC", minutes: 17),
            ],
            arrangement: .besideTrack
        ) { previewNames[$0] ?? $0.rawValue }
        TripLine(station: "Hilversum", steps: [.ride(train: "IC", minutes: 13)], arrangement: .besideTrack) {
            previewNames[$0] ?? $0.rawValue
        }
    }
    .padding(16)
    .background { TrackdownColor.background }
}

#Preview("On a card, dark") {
    TrackdownFont.register()
    return TripLine(
        station: "Maastricht",
        steps: [.ride(train: "IC", minutes: 122), .change(station: nil, minutes: 6), .ride(train: "IC", minutes: 17)]
    ) { $0.rawValue }
    .padding(16)
    .background { RoundedRectangle(cornerRadius: 24).fill(TrackdownColor.surface) }
    .backgroundStyle(TrackdownColor.surface)
    .padding(16)
    .background { TrackdownColor.background }
    .preferredColorScheme(.dark)
}
