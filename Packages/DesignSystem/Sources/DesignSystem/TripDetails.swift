import Foundation
import GameCore
import SwiftUI

/// One guess's trip ride by ride: the ``TripLine`` turned on its side, as trackdown.nl shows it when a guess is tapped.
///
/// Top to bottom: the guessed station with the guess dot; each ride with its train code in a chip of its line color,
/// the train spelled out ("Sprinter", "LNER") and its time; each change as a ring with its station and its wait
/// ("6m to change"); and the mystery station under an ink disc. A change the player has not found stays
/// "Unknown station" with a "?" ring, as on the line.
///
/// The guess dot's halo takes the environment's `backgroundStyle`, or ``TrackdownColor/background`` when none is set.
public struct TripDetails: View {
    private let stops: [TripDetailStop]

    /// - Parameters:
    ///   - station: The guessed station's name.
    ///   - steps: The trip from the guessed station to the mystery station.
    ///   - stationName: The display name for a change station's code.
    public init(station: String, steps: [TripStep], stationName: (StationCode) -> String) {
        stops = TripDetailStop.stops(station: station, steps: steps, stationName: stationName)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(stops.indices, id: \.self) { index in
                TripDetailRow(stop: stops[index])
            }
        }
        .foregroundStyle(TrackdownColor.ink)
    }
}

/// One row of ``TripDetails``.
enum TripDetailStop: Sendable, Hashable {
    /// The guessed station, where the first ride (`below`) leaves.
    case start(name: String, below: Int?)
    /// A ride on line `line` (an index into ``TrackdownColor/lines``).
    case ride(train: TrainType, minutes: Int, line: Int)
    /// A change between the rides on lines `above` and `below`. `name` is `nil` while the station is hidden.
    case change(name: String?, minutes: Int, above: Int?, below: Int?)
    /// The mystery station, where the last ride (`above`) arrives.
    case end(above: Int?)

    static func stops(station: String, steps: [TripStep], stationName: (StationCode) -> String) -> [TripDetailStop] {
        // The line of each step's ride, as on the trip line: first, second, then third for the rest.
        var rides = 0
        let lines: [Int?] = steps.map { step in
            guard case .ride = step else { return nil }
            defer { rides += 1 }
            return min(rides, TrackdownColor.lines.count - 1)
        }

        var stops: [TripDetailStop] = [.start(name: station, below: lines.compactMap { $0 }.first)]
        for (index, step) in steps.enumerated() {
            switch step {
            case .ride(let train, let minutes):
                stops.append(.ride(train: train, minutes: minutes, line: lines[index] ?? 0))
            case .change(let code, let minutes):
                stops.append(
                    .change(
                        name: code.map(stationName),
                        minutes: minutes,
                        above: index > 0 ? lines[index - 1] : nil,
                        below: index + 1 < lines.count ? lines[index + 1] : nil
                    ))
            }
        }
        stops.append(.end(above: lines.compactMap { $0 }.last))
        return stops
    }
}

extension TrainType {
    /// The train spelled out: the train type on the Dutch network ("Sprinter", "Stopping train"), the operator in
    /// Great Britain ("LNER" for `GR`). The code itself for a type the app does not know yet.
    public var name: String {
        Bundle.module.localizedString(forKey: "train.\(rawValue)", value: rawValue, table: nil)
    }
}

private struct TripDetailRow: View {
    let stop: TripDetailStop

    @ScaledMetric(relativeTo: .subheadline) private var stopHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .subheadline) private var rideHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var markerSize: CGFloat = 18
    @Environment(\.backgroundStyle) private var backgroundStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var textLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        HStack(spacing: 12) {
            rail
            textLayout {
                label
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let time {
                    Text(time)
                        .font(TrackdownFont.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(TrackdownColor.muted)
                } else {
                    EmptyView()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: isRide ? rideHeight : stopHeight)
        .accessibilityElement(children: .combine)
    }

    private var isRide: Bool {
        if case .ride = stop { return true }
        return false
    }

    /// This stop's piece of the vertical line: the arriving ride's color above, the leaving one's below, the marker
    /// on the join.
    private var rail: some View {
        let (above, below): (Int?, Int?) =
            switch stop {
            case .start(_, let below): (nil, below)
            case .ride(_, _, let line): (line, line)
            case .change(_, _, let above, let below): (above, below)
            case .end(let above): (above, nil)
            }
        return VStack(spacing: 0) {
            segment(above)
            segment(below)
        }
        .frame(width: 6)
        .overlay { marker }
        .frame(width: markerSize + 2)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func segment(_ line: Int?) -> some View {
        if let line {
            Rectangle().fill(TrackdownColor.lines[line])
        } else {
            SwiftUI.Color.clear
        }
    }

    @ViewBuilder
    private var marker: some View {
        switch stop {
        case .start:
            Circle()
                .fill(TrackdownColor.ink)
                .background {
                    Circle()
                        .fill(backgroundStyle ?? AnyShapeStyle(TrackdownColor.background))
                        .padding(-3)
                }
                .frame(width: markerSize, height: markerSize)
        case .change(let name, _, _, _):
            Circle()
                .strokeBorder(TrackdownColor.ink, lineWidth: 3)
                .background { Circle().fill(TrackdownColor.surface) }
                .overlay {
                    if name == nil {
                        Text(verbatim: "?")
                            .font(TrackdownFont.lineLabel)
                    } else {
                        EmptyView()
                    }
                }
                .frame(width: markerSize, height: markerSize)
        case .end:
            Circle()
                .fill(TrackdownColor.ink)
                .frame(width: markerSize, height: markerSize)
        case .ride:
            EmptyView()
        }
    }

    @ViewBuilder
    private var label: some View {
        switch stop {
        case .start(let name, _):
            Text(name).font(TrackdownFont.subheadlineEmphasized)
        case .ride(let train, _, let line):
            HStack(spacing: 8) {
                Text(verbatim: train.rawValue)
                    .font(TrackdownFont.lineLabel)
                    .foregroundStyle(TrackdownColor.onLine)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background { RoundedRectangle(cornerRadius: 5).fill(TrackdownColor.lines[line]) }
                Text(train.name)
                    .font(TrackdownFont.subheadline)
            }
        case .change(let name?, _, _, _):
            Text(name).font(TrackdownFont.subheadlineEmphasized)
        case .change(nil, _, _, _):
            Text(String(localized: .tripDetailsUnknownStation))
                .font(TrackdownFont.subheadline)
                .foregroundStyle(TrackdownColor.muted)
        case .end:
            Text(String(localized: .tripDetailsMysteryStation))
                .font(TrackdownFont.subheadlineEmphasized)
        }
    }

    private var time: String? {
        switch stop {
        case .ride(_, let minutes, _): minutes.formatted(.tripDuration)
        case .change(_, let minutes, _, _): String(localized: .tripDetailsWait(minutes.formatted(.tripDuration)))
        case .start, .end: nil
        }
    }
}

// MARK: - Previews

#Preview("Trip details") {
    TrackdownFont.register()
    return TripDetails(
        station: "Vlissingen",
        steps: [
            .ride(train: "IC", minutes: 58), .change(station: nil, minutes: 4),
            .ride(train: "SPR", minutes: 41), .change(station: "ut", minutes: 7),
            .ride(train: "ICD", minutes: 22),
        ]
    ) { $0 == "ut" ? "Utrecht Centraal" : $0.rawValue }
    .padding(16)
    .background { TrackdownColor.surface }
}

#Preview("Trip details, dark") {
    TrackdownFont.register()
    return TripDetails(
        station: "Maastricht",
        steps: [.ride(train: "IC", minutes: 122), .change(station: nil, minutes: 6), .ride(train: "IC", minutes: 17)]
    ) { $0.rawValue }
    .padding(16)
    .background { TrackdownColor.surface }
    .preferredColorScheme(.dark)
}
