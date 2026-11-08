import Foundation
import GameCore
import Testing

@testable import GameScreens

@MainActor
@Suite("Archive model")
struct ArchiveModelTests {
    let service = FakePuzzleService()
    let yesterday = GameKey(network: .nl, number: 141)
    let today = GameKey(network: .nl, number: 142)

    func makeModel(storage: MemoryGameStorage = MemoryGameStorage()) -> (ArchiveModel, GameStore) {
        let store = GameStore(service: service, storage: storage)
        return (ArchiveModel(network: .nl, store: store, service: service, locale: .en), store)
    }

    @Test("Lists every puzzle newest first, today's to continue and the others to play")
    func unplayed() async throws {
        let (model, _) = makeModel()
        await model.load()

        let rows = model.rows
        #expect(rows.map(\.puzzle.number) == [142, 141])
        #expect(rows.map(\.isToday) == [true, false])
        #expect(rows.map(\.progress) == [.notStarted, .notStarted])
        #expect(rows.map(\.station) == [nil, nil])
        #expect(rows[0].action == .continueToday)
        #expect(rows[1].action == .play(ArchivedPuzzle(number: 141, date: PuzzleDate(year: 2026, month: 11, day: 5))))
    }

    @Test("Groups the rows by month")
    func months() async throws {
        let (model, _) = makeModel()
        await model.load()

        #expect(model.months.map(\.id) == [202611])
        #expect(model.months.first?.rows.count == 2)
    }

    @Test("Names a finished game's station from the reveal, without replaying its guesses")
    func finished() async throws {
        let storage = MemoryGameStorage([
            yesterday: StoredGame(guesses: ["mt", "ut"], archive: true, outcome: .won)
        ])
        let (model, _) = makeModel(storage: storage)
        await model.load()

        let row = try #require(model.rows.first { $0.key == yesterday })
        #expect(row.progress == .solved(guesses: 2, maxGuesses: 6))
        #expect(row.station == "Utrecht Centraal")
        #expect(row.action == .results(yesterday))
        #expect(service.guesses.isEmpty)
        #expect(storage.load(yesterday)?.station == "ut")
    }

    @Test("A missed game shows its station")
    func missed() async throws {
        let storage = MemoryGameStorage([
            yesterday: StoredGame(guesses: ["mt", "hlm", "gn", "zl", "asd", "asdz"], archive: true, outcome: .lost)
        ])
        let (model, _) = makeModel(storage: storage)
        await model.load()

        let row = try #require(model.rows.first { $0.key == yesterday })
        #expect(row.progress == .missed)
        #expect(row.station == "Utrecht Centraal")
    }

    @Test("Never names the station of a game still on")
    func started() async throws {
        let storage = MemoryGameStorage([yesterday: StoredGame(guesses: ["mt"], archive: true)])
        let (model, _) = makeModel(storage: storage)
        await model.load()

        let row = try #require(model.rows.first { $0.key == yesterday })
        #expect(row.progress == .started(currentGuess: 2, maxGuesses: 6))
        #expect(row.station == nil)
        #expect(row.action == .play(row.puzzle))
    }

    @Test("Follows a game played after the archive loaded")
    func followsPlay() async throws {
        let (model, store) = makeModel()
        await model.load()

        try await store.openArchive(number: 141, network: .nl)
        try await store.submit("mt", to: yesterday)
        #expect(model.rows.first { $0.key == yesterday }?.progress == .started(currentGuess: 2, maxGuesses: 6))

        try await store.submit("ut", to: yesterday)
        await model.load()
        let row = try #require(model.rows.first { $0.key == yesterday })
        #expect(row.progress == .solved(guesses: 2, maxGuesses: 6))
        #expect(row.station == "Utrecht Centraal")
    }

    @Test("Keeps the rows when the station lookup fails")
    func revealFails() async throws {
        service.failReveals(with: .offline)
        let storage = MemoryGameStorage([
            yesterday: StoredGame(guesses: ["ut"], archive: true, outcome: .won)
        ])
        let (model, _) = makeModel(storage: storage)
        await model.load()

        let row = try #require(model.rows.first { $0.key == yesterday })
        #expect(row.progress == .solved(guesses: 1, maxGuesses: 6))
        #expect(row.station == nil)
    }

    @Test("Says why the archive did not load")
    func fails() async throws {
        service.failToday(with: .offline)
        let (model, _) = makeModel()
        await model.load()

        #expect(model.entries == .failed(.offline))
        #expect(model.rows.isEmpty)
    }
}
