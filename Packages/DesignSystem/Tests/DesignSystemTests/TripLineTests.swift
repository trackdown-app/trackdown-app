import CoreGraphics
import Foundation
import Testing

@testable import DesignSystem

@Suite("Trip line width")
struct TripLineWidthTests {
    @Test(
        "Line length is total minutes over 150, clamped to 14 %...100 %",
        arguments: [
            (150, 1.0), (75, 0.5), (300, 1.0), (21, 0.14), (13, 0.14), (0, 0.14), (145, 145.0 / 150),
        ])
    func lineFraction(minutes: Int, expected: Double) {
        #expect(abs(TripLineGeometry.lineFraction(totalMinutes: minutes) - expected) < 0.000_1)
    }

    @Test("A 150-minute line runs from the left edge to the bar's center")
    func fullTrack() {
        let metrics = TripLineMetrics()
        let geometry = TripLineGeometry(pieces: [.ride(minutes: 150)], width: 358, metrics: metrics)
        #expect(geometry.dot.minX == 0)
        #expect(geometry.rides[0].frame.maxX == 358 - metrics.barWidth / 2)
        #expect(geometry.bar.maxX == 358)
        #expect(geometry.bar.width == metrics.barWidth)
    }

    @Test(
        "Without a proposed width, the line is just wide enough for every full label",
        arguments: [
            [TripLinePiece.ride(minutes: 13)],
            [.ride(minutes: 122), .change(minutes: 6), .ride(minutes: 17)],
            [.ride(minutes: 58), .change(minutes: 4), .ride(minutes: 41), .change(minutes: 7), .ride(minutes: 22)],
            [.ride(minutes: 30), .ride(minutes: 10)],
        ])
    func idealWidth(pieces: [TripLinePiece]) {
        let metrics = TripLineMetrics().scaled(by: 1.4)
        let rideCount = pieces.filter { if case .ride = $0 { true } else { false } }.count
        let labels = (0..<rideCount).map { CGFloat(48 + 6 * $0) }
        let width = TripLineGeometry.idealWidth(pieces: pieces, fullLabelWidths: labels, metrics: metrics)
        let geometry = TripLineGeometry(pieces: pieces, width: width, metrics: metrics)
        for (ride, label) in zip(geometry.rides, labels) {
            let fit = TripLineLabelFit.choose(
                full: label, short: 0, available: ride.visible.width, padding: metrics.labelPadding)
            #expect(fit == .full)
        }
        // And no wider than it needs to be: one point less leaves some label without room.
        let narrower = TripLineGeometry(pieces: pieces, width: width - 1, metrics: metrics)
        let allFit = zip(narrower.rides, labels).allSatisfy { ride, label in
            label + 2 * metrics.labelPadding <= ride.visible.width
        }
        #expect(!allFit)
    }

    @Test("A short trip still gets 14 % of the track, right-aligned")
    func shortTrip() {
        let metrics = TripLineMetrics()
        let geometry = TripLineGeometry(pieces: [.ride(minutes: 5)], width: 358, metrics: metrics)
        let track = 358 - metrics.barWidth / 2
        #expect(abs(geometry.dot.minX - track * 0.86) < 0.001)
        #expect(geometry.rides[0].frame.maxX == track)
    }

    @Test("Segment widths follow their minutes; change minutes add length but no width")
    func segmentWidths() throws {
        let metrics = TripLineMetrics()
        // Maastricht: 122 + 6 + 17 = 145 minutes.
        let pieces: [TripLinePiece] = [.ride(minutes: 122), .change(minutes: 6), .ride(minutes: 17)]
        let geometry = TripLineGeometry(pieces: pieces, width: 358, metrics: metrics)
        let first = try #require(geometry.rides.first).frame
        let second = try #require(geometry.rides.last).frame
        #expect(abs(first.width / second.width - 122.0 / 17.0) < 0.001)

        let track = 358 - metrics.barWidth / 2
        let lineWidth = track * 145 / 150
        let fixed = (metrics.lineHeight - metrics.dotOverlap) + (metrics.ringDiameter - 2 * metrics.ringOverlap)
        #expect(abs(first.width + second.width - (lineWidth - fixed)) < 0.001)
        #expect(abs(second.maxX - track) < 0.001)
    }

    @Test("Rings sit on the joins between segments, overlapping each by the ring overlap")
    func ringsOnJoins() throws {
        let metrics = TripLineMetrics()
        let pieces: [TripLinePiece] = [
            .ride(minutes: 40), .change(minutes: 5), .ride(minutes: 30), .change(minutes: 5), .ride(minutes: 20),
        ]
        let geometry = TripLineGeometry(pieces: pieces, width: 358, metrics: metrics)
        #expect(geometry.changes.count == 2)
        for (index, ring) in geometry.changes.enumerated() {
            #expect(abs(ring.minX - (geometry.rides[index].frame.maxX - metrics.ringOverlap)) < 0.001)
            #expect(abs(ring.maxX - (geometry.rides[index + 1].frame.minX + metrics.ringOverlap)) < 0.001)
            #expect(ring.midY == geometry.dot.midY)
        }
        #expect(geometry.rides[0].frame.minX == geometry.dot.maxX - metrics.dotOverlap)
    }

    @Test("A label can use only the part of a segment the dot, rings and bar leave free")
    func visibleParts() {
        let metrics = TripLineMetrics()
        let pieces: [TripLinePiece] = [.ride(minutes: 100), .change(minutes: 5), .ride(minutes: 45)]
        let geometry = TripLineGeometry(pieces: pieces, width: 358, metrics: metrics)
        #expect(geometry.rides[0].visible.minX == geometry.dot.maxX)
        #expect(geometry.rides[0].visible.maxX == geometry.changes[0].minX)
        #expect(geometry.rides[1].visible.minX == geometry.changes[0].maxX)
        #expect(geometry.rides[1].visible.maxX == geometry.bar.minX)
    }

    @Test("Scaling for Dynamic Type grows every part")
    func scaling() {
        let scaled = TripLineMetrics().scaled(by: 2)
        #expect(scaled.lineHeight == 40)
        #expect(scaled.barHeight == 88)
        #expect(scaled.height == 88)
    }
}

@Suite("Trip line labels")
struct TripLineLabelTests {
    @Test(
        "Shows the longest label that fits with padding on both sides",
        arguments: [
            (100.0, TripLineLabelFit.full),
            (68.0, .full),
            (67.9, .short),
            (48.0, .short),
            (47.9, .none),
            (0.0, .none),
        ])
    func choosesLabel(available: CGFloat, expected: TripLineLabelFit) {
        // "IC 2h 02m" is 60 pt wide, "2h 02m" 40 pt; 4 pt padding each side.
        #expect(TripLineLabelFit.choose(full: 60, short: 40, available: available, padding: 4) == expected)
    }

    @Test("A wider track, such as the iPhone Duo detail column, fits more labels than a phone's")
    func widerTrackFitsMore() {
        let metrics = TripLineMetrics()
        // Maastricht: IC 2h 02m, a change, IC 17m. Full labels about 60 and 40 pt wide, short ones 40 and 24 pt.
        let pieces: [TripLinePiece] = [.ride(minutes: 122), .change(minutes: 6), .ride(minutes: 17)]
        let labels: [(full: CGFloat, short: CGFloat)] = [(60, 40), (40, 24)]

        func fits(width: CGFloat) -> [TripLineLabelFit] {
            let geometry = TripLineGeometry(pieces: pieces, width: width, metrics: metrics)
            return zip(geometry.rides, labels).map { ride, label in
                TripLineLabelFit.choose(
                    full: label.full, short: label.short, available: ride.visible.width, padding: metrics.labelPadding)
            }
        }

        func rank(_ fit: TripLineLabelFit) -> Int {
            switch fit {
            case .none: 0
            case .short: 1
            case .full: 2
            }
        }

        // A phone's column, and the detail column beside the 300 pt archive sidebar.
        let phone = fits(width: 326)
        let duo = fits(width: 507)
        #expect(zip(phone, duo).allSatisfy { rank($0) <= rank($1) })
        #expect(phone.map(rank).reduce(0, +) < duo.map(rank).reduce(0, +))
    }
}

@Suite("Trip duration")
struct TripDurationTests {
    @Test(
        "Matches the web's format",
        arguments: [(145, "2h 25m"), (122, "2h 02m"), (17, "17m"), (60, "1h 00m"), (0, "0m"), (605, "10h 05m")])
    func compact(minutes: Int, expected: String) {
        #expect(minutes.formatted(.tripDuration.locale(Locale(identifier: "en"))) == expected)
    }

    @Test("Dutch compact times use Dutch hour units")
    func dutchCompact() {
        let style = TripDurationFormatStyle(locale: Locale(identifier: "nl_NL"))
        #expect(style.format(122) == "2u 02m")
        #expect(style.format(17) == "17m")
        #expect(style.format(0) == "0m")
    }

    @Test("Spells the units out for VoiceOver")
    func spoken() {
        let style = TripDurationFormatStyle(width: .spoken, locale: Locale(identifier: "en_US"))
        #expect(style.format(145) == "2 hours, 25 minutes")
        #expect(style.format(17) == "17 minutes")
    }
}

@Suite("Trip summary")
struct TripSummaryTests {
    @Test("Says how the trip changes trains")
    func summaries() {
        #expect(TripSummary(changeNames: []) == .direct)
        #expect(TripSummary(changeNames: [nil]) == .change(at: nil))
        #expect(TripSummary(changeNames: ["Utrecht Centraal"]) == .change(at: "Utrecht Centraal"))
        #expect(TripSummary(changeNames: [nil, "Utrecht Centraal"]) == .changes(2))
    }

    @Test("Reads as text and as the end of a VoiceOver label")
    func texts() {
        #expect(TripSummary.direct.text == "Direct")
        #expect(TripSummary.change(at: nil).text == "Change at a hidden station")
        #expect(TripSummary.change(at: nil).spokenText == "change at a hidden station")
        #expect(TripSummary.change(at: "Utrecht Centraal").text == "Change at Utrecht Centraal")
        #expect(TripSummary.changes(2).text == "2 changes")
    }
}
