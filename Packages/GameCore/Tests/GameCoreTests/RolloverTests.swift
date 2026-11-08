import Foundation
import GameCore
import Testing

@MainActor
struct RolloverTests {
    private func makeStore(clock: FakeClock, service: FakePuzzleService) -> GameStore {
        GameStore(
            service: service,
            storage: MemoryGameStorage(),
            now: { clock.now },
            sleep: { try clock.sleep(for: $0) }
        )
    }

    private static let hour: Duration = .seconds(60 * 60)

    @Test(
        "Waits for midnight in Amsterdam across clock changes, then plays the new puzzle",
        arguments: [
            // Clocks go forward on 29 March: that day is 23 hours long.
            ("2026-03-28T12:00:00+01:00", [12, 23], "2026-03-30"),
            // Clocks go back on 25 October: that day is 25 hours long.
            ("2026-10-24T12:00:00+02:00", [12, 25], "2026-10-26"),
            // An ordinary winter day.
            ("2026-01-14T12:00:00+01:00", [12, 24], "2026-01-16"),
        ] as [(String, [Int], String)])
    func followsMidnight(start: String, sleepHours: [Int], finalDay: String) async throws {
        let expectedSleeps = sleepHours.map { Self.hour * $0 }
        let clock = FakeClock(try .iso(start), sleepsLeft: expectedSleeps.count)
        let service = FakePuzzleService(clock: clock)
        let store = makeStore(clock: clock, service: service)
        try await store.loadToday(network: .nl)

        await store.followRollover(network: .nl)

        #expect(clock.sleeps == expectedSleeps)
        let today = try #require(store.today[.nl])
        #expect(today.date == PuzzleDate(iso8601: finalDay))
        #expect(store.todaysGame(network: .nl)?.key.number == FakePuzzleService.number(of: today.date))
    }

    @Test("Loads today's puzzle first when none is loaded yet")
    func loadsFirst() async throws {
        let clock = FakeClock(try .iso("2026-03-28T12:00:00+01:00"), sleepsLeft: 0)
        let store = makeStore(clock: clock, service: FakePuzzleService(clock: clock))

        await store.followRollover(network: .nl)

        #expect(store.today[.nl]?.date == PuzzleDate(year: 2026, month: 3, day: 28))
    }

    @Test("Asks again shortly when the server's clock has not reached midnight yet")
    func serverBehind() async throws {
        let clock = FakeClock(try .iso("2026-03-28T23:00:00+01:00"), sleepsLeft: 3)
        let service = FakePuzzleService(clock: clock)
        let store = makeStore(clock: clock, service: service)
        store.retryDelay = .seconds(30)
        try await store.loadToday(network: .nl)
        service.lagBehind(by: 10)

        await store.followRollover(network: .nl)

        // One hour to midnight, the old puzzle again, 30 seconds later the new one, then on to the next midnight.
        let sleeps = clock.sleeps
        #expect(sleeps.prefix(2) == [Self.hour, .seconds(30)])
        #expect(store.today[.nl]?.date == PuzzleDate(year: 2026, month: 3, day: 29))
    }

    @Test("Puts a game in progress aside at rollover and keeps it for the archive")
    func keepsYesterday() async throws {
        let clock = FakeClock(try .iso("2026-03-28T22:00:00+01:00"), sleepsLeft: 1)
        let service = FakePuzzleService(clock: clock)
        let store = makeStore(clock: clock, service: service)
        let yesterday = try await store.loadToday(network: .nl)
        try await store.submit("ut", to: yesterday.key)

        await store.followRollover(network: .nl)

        #expect(store.todaysGame(network: .nl)?.key.number == yesterday.key.number + 1)
        #expect(store.todaysGame(network: .nl)?.guesses == [])
        #expect(store.games[yesterday.key]?.guesses == ["ut"])
    }
}
