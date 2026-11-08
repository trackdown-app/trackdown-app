import Analytics
import Foundation
import GameCore
import Testing

@testable import GameScreens

@MainActor
private final class RecordingAnalytics: AnalyticsClient {
    var events: [AnalyticsEvent] = []

    func capture(_ event: AnalyticsEvent) { events.append(event) }
    func setConsent(_ consent: AnalyticsConsent) {}
}

@MainActor
@Suite("Gameplay analytics")
struct GameplayAnalyticsTests {
    private let analytics = RecordingAnalytics()
    private let service = FakePuzzleService()
    private let dailyKey = GameKey(network: .nl, number: 142)
    private let archiveKey = GameKey(network: .nl, number: 141)
    private let archived = ArchivedPuzzle(number: 141, date: PuzzleDate(year: 2026, month: 11, day: 5))
    private let daily = PuzzleEventProperties(network: .nl, puzzleNumber: 142, archive: false)
    private let past = PuzzleEventProperties(network: .nl, puzzleNumber: 141, archive: true)

    private func model(puzzle: PlayedPuzzle = .today, storage: MemoryGameStorage = MemoryGameStorage()) -> PlayingModel
    {
        PlayingModel(
            puzzle: puzzle, network: .nl, store: GameStore(service: service, storage: storage), service: service,
            locale: .en, analytics: analytics
        )
    }

    @Test("Only accepted guesses start a puzzle, with one-based counts and one completion")
    func acceptedGuesses() async {
        let model = model()
        await model.load()
        #expect(analytics.events.isEmpty)

        model.query = "Atlantis"
        await model.guess()
        service.failGuesses(with: .offline)
        model.query = "Haarlem"
        await model.guess()
        #expect(analytics.events.isEmpty)

        service.failGuesses(with: nil)
        await model.guess()
        model.query = "Haarlem"
        await model.guess()
        model.query = "Utrecht"
        await model.guess()
        await model.guess()
        await model.load()

        #expect(
            analytics.events == [
                .puzzleStarted(daily), .guessMade(daily, guessNumber: 1),
                .guessMade(daily, guessNumber: 2), .puzzleSolved(daily, guessesUsed: 2),
            ])
    }

    @Test("Restoring a game never emits start, guess or completion events", arguments: [false, true])
    func restoreIsSilent(finished: Bool) async {
        let storage = MemoryGameStorage([
            dailyKey: StoredGame(guesses: finished ? ["ut"] : ["mt"], outcome: finished ? .won : nil)
        ])
        let model = model(storage: storage)
        await model.load()
        await model.load()
        #expect(analytics.events.isEmpty)
    }

    @Test("The final wrong guess emits a miss without restarting the restored game")
    func missed() async {
        let storage = MemoryGameStorage([
            dailyKey: StoredGame(guesses: ["mt", "hlm", "asdz", "asd", "gn"])
        ])
        let model = model(storage: storage)
        await model.load()
        model.query = "Zwolle"
        await model.guess()
        #expect(analytics.events == [.guessMade(daily, guessNumber: 6), .puzzleMissed(daily, guessesUsed: 6)])
    }

    @Test("The first accepted archive guess records play once across reopening")
    func archiveStarted() async {
        let storage = MemoryGameStorage()
        let first = model(puzzle: .archive(archived), storage: storage)
        await first.load()
        service.failGuesses(with: .offline)
        first.query = "Maastricht"
        await first.guess()
        #expect(analytics.events.isEmpty)

        service.failGuesses(with: nil)
        await first.guess()
        let reopened = model(puzzle: .archive(archived), storage: storage)
        await reopened.load()
        reopened.query = "Utrecht"
        await reopened.guess()
        #expect(
            analytics.events == [
                .puzzleStarted(past), .archivePuzzlePlayed(past), .guessMade(past, guessNumber: 1),
                .guessMade(past, guessNumber: 2), .puzzleSolved(past, guessesUsed: 2),
            ])
        #expect(storage.load(archiveKey)?.archive == true)
    }

    @Test("A resumed daily game becomes an archive game on its first successful archive guess")
    func dailyResumedInArchive() async {
        let storage = MemoryGameStorage([archiveKey: StoredGame(guesses: ["mt"])])
        let model = model(puzzle: .archive(archived), storage: storage)
        await model.load()
        #expect(analytics.events.isEmpty)
        #expect(storage.load(archiveKey)?.archive == false)
        service.failGuesses(with: .offline)
        model.query = "Haarlem"
        await model.guess()
        #expect(storage.load(archiveKey)?.archive == false)
        #expect(analytics.events.isEmpty)

        service.failGuesses(with: nil)
        await model.guess()
        model.query = "Utrecht"
        await model.guess()
        #expect(
            analytics.events == [
                .archivePuzzlePlayed(past), .guessMade(past, guessNumber: 2),
                .guessMade(past, guessNumber: 3), .puzzleSolved(past, guessesUsed: 3),
            ])
        #expect(model.game?.isArchive == true)
        #expect(storage.load(archiveKey)?.archive == true)
    }

    @Test("A completed share or copy sends only safe puzzle metadata", arguments: AnalyticsEvent.ShareMethod.allCases)
    func shares(method: AnalyticsEvent.ShareMethod) async throws {
        let store = GameStore(service: service, storage: MemoryGameStorage())
        try await store.openArchive(number: archiveKey.number, network: .nl)
        try await store.submit("ut", to: archiveKey)
        let model = ResultsModel(key: archiveKey, store: store, service: service, analytics: analytics)
        await model.load()
        #expect(analytics.events.isEmpty)
        model.shareCompleted(method: method, completed: true, error: nil)
        #expect(analytics.events == [.resultShared(past, method: method)])
    }

    @Test("Cancelled and failed shares do not emit result_shared", arguments: [false, true])
    func unsuccessfulShare(failed: Bool) async throws {
        let store = GameStore(service: service, storage: MemoryGameStorage())
        try await store.loadToday(network: .nl)
        try await store.submit("ut", to: dailyKey)
        let model = ResultsModel(key: dailyKey, store: store, service: service, analytics: analytics)
        model.shareCompleted(method: .shared, completed: failed, error: failed ? PuzzleServiceError.offline : nil)
        #expect(analytics.events.isEmpty)
    }

    @Test("An unfinished puzzle cannot emit result_shared")
    func unfinishedShare() async throws {
        let store = GameStore(service: service, storage: MemoryGameStorage())
        try await store.loadToday(network: .nl)
        let model = ResultsModel(key: dailyKey, store: store, service: service, analytics: analytics)
        model.shareCompleted(method: .copied, completed: true, error: nil)
        #expect(analytics.events.isEmpty)
    }
}
