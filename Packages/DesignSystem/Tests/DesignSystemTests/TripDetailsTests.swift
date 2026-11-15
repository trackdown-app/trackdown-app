import GameCore
import Testing

@testable import DesignSystem

@Suite("Trip details")
struct TripDetailsTests {
    private let names: [StationCode: String] = ["ut": "Utrecht Centraal"]

    @Test("Lists a direct trip from the guess to the mystery station")
    func direct() {
        let stops = TripDetailStop.stops(station: "Hilversum", steps: [.ride(train: "IC", minutes: 13)]) {
            names[$0]
        }

        let expected: [TripDetailStop] = [
            .start(name: "Hilversum", below: 0),
            .ride(train: "IC", minutes: 13, line: 0),
            .end(above: 0),
        ]
        #expect(stops == expected)
    }

    @Test("Colors each ride by its line and joins changes between them, hidden ones without a name")
    func changes() {
        let stops = TripDetailStop.stops(
            station: "Vlissingen",
            steps: [
                .ride(train: "IC", minutes: 58), .change(station: nil, minutes: 4),
                .ride(train: "SPR", minutes: 41), .change(station: "ut", minutes: 7),
                .ride(train: "ICD", minutes: 22), .change(station: nil, minutes: 3),
                .ride(train: "ST", minutes: 9),
            ]
        ) { names[$0] }

        let expected: [TripDetailStop] = [
            .start(name: "Vlissingen", below: 0),
            .ride(train: "IC", minutes: 58, line: 0),
            .change(station: .hidden, minutes: 4, above: 0, below: 1),
            .ride(train: "SPR", minutes: 41, line: 1),
            .change(station: .named("Utrecht Centraal"), minutes: 7, above: 1, below: 2),
            .ride(train: "ICD", minutes: 22, line: 2),
            // A fourth train keeps the third line's color, as on the trip line.
            .change(station: .hidden, minutes: 3, above: 2, below: 2),
            .ride(train: "ST", minutes: 9, line: 2),
            .end(above: 2),
        ]
        #expect(stops == expected)
    }

    @Test("Calls a revealed change outside the network a station abroad, not its code")
    func abroad() {
        let stops = TripDetailStop.stops(
            station: "Brussel-Zuid",
            steps: [
                .ride(train: "IC", minutes: 170), .change(station: "8200100", minutes: 9),
                .ride(train: "IC", minutes: 25),
            ]
        ) { names[$0] }

        #expect(stops[2] == .change(station: .abroad, minutes: 9, above: 0, below: 1))
        #expect(String(localized: .tripDetailsStationAbroad) == "Station abroad")
    }

    @Test("A correct guess has no rides between the guess and the mystery station")
    func noSteps() {
        let stops = TripDetailStop.stops(station: "Amersfoort Centraal", steps: []) { $0.rawValue }

        #expect(stops == [.start(name: "Amersfoort Centraal", below: nil), .end(above: nil)])
    }

    @Test(
        "Spells out train codes, and keeps a code it does not know",
        arguments: [
            (TrainType("SPR"), "Sprinter"),
            ("ST", "Stopping train"),
            ("GR", "LNER"),
            ("XYZ", "XYZ"),
        ])
    func trainNames(train: TrainType, name: String) {
        #expect(train.name == name)
    }
}
