import Foundation
import GameCore
import Testing

@testable import GameScreens

@MainActor
@Suite("Playing model")
struct PlayingModelTests {
    let service = FakePuzzleService()

    func makeModel(
        puzzle: PlayedPuzzle = .today,
        storage: MemoryGameStorage = MemoryGameStorage()
    ) -> PlayingModel {
        PlayingModel(
            puzzle: puzzle,
            network: .nl,
            store: GameStore(service: service, storage: storage),
            service: service,
            locale: .en
        )
    }

    @Test("Loads today's puzzle and its stations")
    func loadsToday() async throws {
        let model = makeModel()
        await model.load()

        #expect(model.loadState == .ready)
        #expect(model.key == GameKey(network: .nl, number: 142))
        #expect(model.date == PuzzleDate(year: 2026, month: 11, day: 6))
        #expect(model.currentGuess == 1)
        #expect(model.rows.isEmpty)
        #expect(model.canGuess)
    }

    @Test("Restores stored guesses, newest first")
    func restoresGuessesNewestFirst() async throws {
        let key = GameKey(network: .nl, number: 142)
        let storage = MemoryGameStorage([key: StoredGame(guesses: ["mt", "hlm"], archive: false, outcome: nil)])
        let model = makeModel(storage: storage)
        await model.load()

        #expect(model.rows.map(\.number) == [2, 1])
        #expect(model.rows.map(\.station) == ["Haarlem", "Maastricht"])
        #expect(model.currentGuess == 3)
    }

    @Test("Typing highlights the best match and Guess sends it")
    func guessesTheHighlightedMatch() async throws {
        let model = makeModel()
        await model.load()

        model.query = "ams"
        #expect(model.suggestions.map(\.name) == ["Amsterdam Centraal", "Amsterdam Zuid"])
        #expect(model.selection == "asd")

        let over = await model.guess()
        #expect(!over)
        #expect(service.guesses == ["asd"])
        #expect(model.query.isEmpty)
        #expect(model.rows.first?.station == "Amsterdam Centraal")
        #expect(model.lastGuess == SubmittedGuess(sequence: 1, solved: false))
    }

    @Test("Refuses a station already guessed without calling the server")
    func refusesDuplicates() async throws {
        let model = makeModel()
        await model.load()
        model.query = "Haarlem"
        await model.guess()

        model.query = "haarlem"
        #expect(model.selection == nil)
        await model.guess()

        #expect(model.message == .alreadyGuessed("Haarlem"))
        #expect(service.guesses == ["hlm"])
    }

    @Test("Refuses a name that is not a station")
    func refusesUnknownStations() async throws {
        let model = makeModel()
        await model.load()

        model.query = "Atlantis"
        await model.guess()

        #expect(model.message == .unknownStation)
        #expect(service.guesses.isEmpty)
    }

    @Test("Typing again clears the message")
    func typingClearsTheMessage() async throws {
        let model = makeModel()
        await model.load()
        model.query = "Atlantis"
        await model.guess()

        model.query = "Atlantis C"
        #expect(model.message == nil)
    }

    @Test("A rate-limited guess says how long to wait")
    func rateLimitedGuess() async throws {
        let model = makeModel()
        await model.load()
        service.failGuesses(with: .rateLimited(retryAfter: .seconds(30)))

        model.query = "Haarlem"
        await model.guess()

        #expect(model.message == .problem(.rateLimited(retryAfter: .seconds(30))))
        #expect(model.query == "Haarlem")
        #expect(model.rows.isEmpty)
    }

    @Test("Solving ends the game and asks for the Solved sheet")
    func solving() async throws {
        let model = makeModel()
        await model.load()

        model.query = "Utrecht"
        let over = await model.guess()

        #expect(over)
        #expect(model.game?.status == .solved)
        #expect(model.lastGuess?.solved == true)
        #expect(!model.canGuess)
        #expect(model.currentGuess == 1)
    }

    @Test("The last miss ends the game")
    func lastMiss() async throws {
        let key = GameKey(network: .nl, number: 142)
        let storage = MemoryGameStorage([
            key: StoredGame(guesses: ["mt", "hlm", "asdz", "asd", "gn"], archive: false, outcome: nil)
        ])
        let model = makeModel(storage: storage)
        await model.load()
        #expect(model.currentGuess == 6)

        model.query = "Zwolle"
        let over = await model.guess()

        #expect(over)
        #expect(model.game?.status == .lost)
        #expect(model.lastGuess?.solved == false)
        #expect(model.currentGuess == 6)
    }

    @Test("Says a station is guessed when every match is")
    func everyMatchGuessed() async throws {
        let model = makeModel()
        await model.load()
        model.query = "Haarlem"
        await model.guess()

        model.query = "Haar"
        await model.guess()

        #expect(model.message == .alreadyGuessed("Haarlem"))
        #expect(service.guesses == ["hlm"])
    }

    @Test(
        "Maps load failures to what the screen shows",
        arguments: [
            (PuzzleServiceError.offline, PlayingProblem.offline),
            (.unknownClient, .updateRequired),
            (.rateLimited(retryAfter: .seconds(90)), .rateLimited(retryAfter: .seconds(90))),
            (.internalError, .unavailable),
        ])
    func loadFailures(error: PuzzleServiceError, problem: PlayingProblem) async throws {
        service.failToday(with: error)
        let model = makeModel()
        await model.load()

        #expect(model.loadState == .failed(problem))

        service.failToday(with: nil)
        await model.load()
        #expect(model.loadState == .ready)
    }

    @Test("Plays a past puzzle from the archive")
    func archivePuzzle() async throws {
        let archived = ArchivedPuzzle(number: 141, date: PuzzleDate(year: 2026, month: 11, day: 5))
        let model = makeModel(puzzle: .archive(archived))
        await model.load()

        #expect(model.key == GameKey(network: .nl, number: 141))
        #expect(model.date == archived.date)
        #expect(model.game?.isArchive == true)

        model.query = "Maastricht"
        await model.guess()
        #expect(model.rows.map(\.code) == ["mt"])
    }
}

@Suite("Playing screen formatting")
struct FormattingTests {
    @Test("Titles a puzzle day like the design")
    func dayTitle() {
        let date = PuzzleDate(year: 2026, month: 11, day: 6)
        #expect(date.title(locale: Locale(identifier: "en_GB")) == "Friday 6 November")
        #expect(date.title(locale: Locale(identifier: "nl_NL")) == "Vrijdag 6 november")
    }

    @Test(
        "Spells out the Retry-After wait",
        arguments: [
            (Duration.seconds(30), "30 seconds"),
            (.seconds(125), "2 minutes, 5 seconds"),
            (.zero, "1 second"),
        ])
    func retryText(wait: Duration, text: String) {
        #expect(wait.retryText(locale: Locale(identifier: "en_GB")) == text)
    }
}
