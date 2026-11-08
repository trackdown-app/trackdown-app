import Foundation
import GameCore
import Testing

struct StoredGameTests {
    @Test("Uses the website's localStorage key")
    func storageKey() {
        #expect(GameKey(network: .nl, number: 123).storageKey == "trackdown:game:v1:nl:123")
        #expect(GameKey(network: .gb, number: 7).storageKey == "trackdown:game:v1:gb:7")
    }

    @Test("Encodes like the website: guesses only for a game played on its day")
    func encodesTodaysGame() throws {
        let data = try JSONEncoder().encode(StoredGame(guesses: ["ut", "gvc"]))

        #expect(String(decoding: data, as: UTF8.self) == #"{"guesses":["ut","gvc"]}"#)
    }

    @Test("Encodes like the website: archive true for an archive game")
    func encodesArchiveGame() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(StoredGame(guesses: ["ut"], archive: true))

        #expect(String(decoding: data, as: UTF8.self) == #"{"archive":true,"guesses":["ut"]}"#)
    }

    @Test("Encodes a finished game's outcome")
    func encodesOutcome() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(StoredGame(guesses: ["asd"], outcome: .won))

        #expect(String(decoding: data, as: UTF8.self) == #"{"guesses":["asd"],"outcome":"won"}"#)
    }

    @Test(
        "Decodes the website's value, with or without archive and outcome",
        arguments: [
            (#"{"guesses":["ut"]}"#, StoredGame(guesses: ["ut"])),
            (#"{"guesses":["ut"],"archive":false}"#, StoredGame(guesses: ["ut"])),
            (#"{"guesses":[],"archive":true}"#, StoredGame(guesses: [], archive: true)),
            (#"{"guesses":["asd"],"outcome":"won"}"#, StoredGame(guesses: ["asd"], outcome: .won)),
            (#"{"guesses":["ut"],"outcome":"lost"}"#, StoredGame(guesses: ["ut"], outcome: .lost)),
            (#"{"guesses":["ut"],"outcome":"draw"}"#, StoredGame(guesses: ["ut"])),
        ])
    func decodes(json: String, expected: StoredGame) throws {
        #expect(try JSONDecoder().decode(StoredGame.self, from: Data(json.utf8)) == expected)
    }
}

struct FileGameStorageTests {
    private let storage = FileGameStorage(
        directory: URL.temporaryDirectory.appending(path: "FileGameStorageTests-\(UUID())", directoryHint: .isDirectory)
    )

    @Test("Has nothing for a game never stored")
    func missing() {
        #expect(storage.load(GameKey(network: .nl, number: 1)) == nil)
    }

    @Test("Keeps each game apart and reads it back")
    func roundTrips() throws {
        let today = GameKey(network: .nl, number: 10)
        let archive = GameKey(network: .nl, number: 3)
        let otherNetwork = GameKey(network: .gb, number: 10)

        try storage.save(StoredGame(guesses: ["ut"]), for: today)
        try storage.save(StoredGame(guesses: ["gvc", "ht"], archive: true), for: archive)

        #expect(storage.load(today) == StoredGame(guesses: ["ut"]))
        #expect(storage.load(archive) == StoredGame(guesses: ["gvc", "ht"], archive: true))
        #expect(storage.load(otherNetwork) == nil)
    }

    @Test("Replaces a game when it is stored again")
    func replaces() throws {
        let key = GameKey(network: .nl, number: 10)

        try storage.save(StoredGame(guesses: ["ut"]), for: key)
        try storage.save(StoredGame(guesses: ["ut", "gvc"]), for: key)

        #expect(storage.load(key) == StoredGame(guesses: ["ut", "gvc"]))
    }

    @Test("Treats a file it cannot decode as missing")
    func corrupt() throws {
        let key = GameKey(network: .nl, number: 10)
        try storage.save(StoredGame(guesses: ["ut"]), for: key)
        try Data("not json".utf8).write(to: storage.directory.appending(path: "nl-10.json"))

        #expect(storage.load(key) == nil)
    }
}
