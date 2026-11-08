import GameCore
import Testing

/// The website's cases (`src/lib/game/statistics.test.ts`), with the same puzzles, games and expectations.
struct StatisticsTests {
    /// Puzzles 1 to `count`, one a day from 1 November 2026.
    private func puzzles(_ count: Int) -> [ArchivedPuzzle] {
        (1...count).map { ArchivedPuzzle(number: $0, date: PuzzleDate(year: 2026, month: 11, day: $0)) }
    }

    /// A game solved in `count` guesses, on its own day unless played in the archive.
    private func won(_ count: Int, archive: Bool = false) -> Statistics.FinishedGame {
        Statistics.FinishedGame(solved: true, guessCount: count, archive: archive)
    }

    private let lost = Statistics.FinishedGame(solved: false, guessCount: 6, archive: false)

    @Test("Is all zeros before the first game")
    func zeros() {
        #expect(
            Statistics(puzzles: puzzles(3), games: [Int: Statistics.FinishedGame](), maxGuesses: 6)
                == Statistics(
                    played: 0,
                    won: 0,
                    winPercent: 0,
                    currentStreak: 0,
                    bestStreak: 0,
                    distribution: [0, 0, 0, 0, 0, 0],
                    missed: 0,
                    today: nil
                )
        )
    }

    @Test("Counts played, won, the percentage and the guesses needed")
    func counts() {
        let statistics = Statistics(
            puzzles: puzzles(4),
            games: [1: won(3), 2: won(3), 3: lost, 4: won(5)],
            maxGuesses: 6
        )

        #expect(statistics.played == 4)
        #expect(statistics.won == 3)
        #expect(statistics.winPercent == 75)
        #expect(statistics.distribution == [0, 0, 2, 0, 1, 0])
        #expect(statistics.missed == 1)
        #expect(statistics.today == .solved(guesses: 5))
    }

    @Test("Leaves a game still on out of the record")
    func gameStillOn() {
        let key = { GameKey(network: .nl, number: $0) }
        let solved = Game(
            key: key(1),
            maxGuesses: 6,
            guesses: ["ut", "asd"],
            trips: [
                GuessTrip(guess: "ut", correct: false, steps: [.ride(train: "IC", minutes: 17)]),
                GuessTrip(guess: "asd", correct: true, steps: []),
            ]
        )
        let playing = Game(
            key: key(2),
            maxGuesses: 6,
            guesses: ["ut", "gvc"],
            trips: [
                GuessTrip(guess: "ut", correct: false, steps: [.ride(train: "IC", minutes: 17)]),
                GuessTrip(guess: "gvc", correct: false, steps: [.ride(train: "IC", minutes: 40)]),
            ]
        )

        let statistics = Statistics(puzzles: puzzles(2), games: [1: solved, 2: playing], maxGuesses: 6)

        #expect(statistics.played == 1)
        #expect(statistics.today == nil)
    }

    @Test("Names today's game as missed when it ran out of guesses")
    func todayMissed() {
        #expect(Statistics(puzzles: puzzles(1), games: [1: lost], maxGuesses: 6).today == .missed)
    }

    @Test("Runs a streak over puzzles won on their own day, today's included")
    func streakIncludesToday() {
        let statistics = Statistics(puzzles: puzzles(3), games: [1: won(4), 2: won(2), 3: won(6)], maxGuesses: 6)

        #expect(statistics.currentStreak == 3)
        #expect(statistics.bestStreak == 3)
    }

    @Test("Keeps yesterday's streak while today's puzzle is still to play")
    func streakWhileTodayToPlay() {
        let notStarted = Statistics(puzzles: puzzles(3), games: [1: won(4), 2: won(2)], maxGuesses: 6)
        let onItsWay = Statistics(
            puzzles: puzzles(3),
            games: [
                1: Game(key: GameKey(network: .nl, number: 1), maxGuesses: 6, guesses: ["asd"], trips: [solvedTrip]),
                2: Game(key: GameKey(network: .nl, number: 2), maxGuesses: 6, guesses: ["asd"], trips: [solvedTrip]),
                3: Game(key: GameKey(network: .nl, number: 3), maxGuesses: 6, guesses: ["ut"], trips: [missTrip]),
            ],
            maxGuesses: 6
        )

        #expect(notStarted.currentStreak == 2)
        #expect(onItsWay.currentStreak == 2)
    }

    @Test("Breaks the streak after a skipped day")
    func skippedDay() {
        let statistics = Statistics(
            puzzles: puzzles(5),
            // 4 November skipped.
            games: [1: won(3), 2: won(3), 3: won(3), 5: won(3)],
            maxGuesses: 6
        )

        #expect(statistics.currentStreak == 1)
        #expect(statistics.bestStreak == 3)
    }

    @Test("Breaks the streak after a missed day")
    func missedDay() {
        let statistics = Statistics(puzzles: puzzles(3), games: [1: won(3), 2: lost, 3: won(3)], maxGuesses: 6)

        #expect(statistics.currentStreak == 1)
        #expect(statistics.bestStreak == 1)
    }

    @Test("Ends the streak once yesterday was skipped, before today is played")
    func yesterdaySkipped() {
        let statistics = Statistics(puzzles: puzzles(3), games: [1: won(3)], maxGuesses: 6)

        #expect(statistics.currentStreak == 0)
        #expect(statistics.bestStreak == 1)
    }

    @Test("Drops the streak to nothing when today's puzzle is lost")
    func todayLost() {
        let statistics = Statistics(puzzles: puzzles(3), games: [1: won(3), 2: won(3), 3: lost], maxGuesses: 6)

        #expect(statistics.currentStreak == 0)
        #expect(statistics.bestStreak == 2)
    }

    @Test("Counts a puzzle won in the archive as played, but not for the streak")
    func archiveGame() {
        let statistics = Statistics(
            puzzles: puzzles(3),
            // Puzzle 2 played from the archive, after its day.
            games: [1: won(3), 2: won(3, archive: true), 3: won(3)],
            maxGuesses: 6
        )

        #expect(statistics.won == 3)
        #expect(statistics.currentStreak == 1)
        #expect(statistics.bestStreak == 1)
    }

    @Test("Follows the puzzles' days, not the order they come in")
    func anyOrder() {
        let statistics = Statistics(puzzles: puzzles(3).reversed(), games: [2: won(3), 3: won(3)], maxGuesses: 6)

        #expect(statistics.currentStreak == 2)
        #expect(statistics.today == .solved(guesses: 3))
    }

    // Not in the website's suite: the app keeps no `correct` per guess, so it reads finished games from `Game`.

    @Test("Counts a game whose trips are not rebuilt yet as not played")
    func restoring() {
        let restoring = Game(key: GameKey(network: .nl, number: 1), maxGuesses: 6, guesses: ["asd"], trips: nil)

        #expect(Statistics.FinishedGame(restoring) == nil)
        #expect(Statistics(puzzles: puzzles(1), games: [1: restoring], maxGuesses: 6).played == 0)
    }

    @Test("Reads a finished game's result and archive mark from the game")
    func finishedFromGame() {
        let solved = Game(
            key: GameKey(network: .nl, number: 1),
            maxGuesses: 6,
            isArchive: true,
            guesses: ["ut", "asd"],
            trips: [missTrip, solvedTrip]
        )
        let lost = Game(
            key: GameKey(network: .nl, number: 2),
            maxGuesses: 2,
            guesses: ["ut", "gvc"],
            trips: [missTrip, missTrip]
        )

        #expect(Statistics.FinishedGame(solved) == Statistics.FinishedGame(solved: true, guessCount: 2, archive: true))
        #expect(Statistics.FinishedGame(lost) == Statistics.FinishedGame(solved: false, guessCount: 2, archive: false))
    }

    private let missTrip = GuessTrip(guess: "ut", correct: false, steps: [.ride(train: "IC", minutes: 17)])
    private let solvedTrip = GuessTrip(guess: "asd", correct: true, steps: [])
}

struct ClosestGuessTests {
    @Test("Is the guess with the lowest total minutes, the earliest on a tie")
    func reveal() {
        let reveal = Reveal(
            station: "asd",
            solved: false,
            guesses: [
                RevealedGuess(guess: "gvc", correct: false, steps: [], totalMinutes: 52),
                RevealedGuess(guess: "ut", correct: false, steps: [], totalMinutes: 17),
                RevealedGuess(guess: "hlm", correct: false, steps: [], totalMinutes: 17),
                RevealedGuess(guess: "ehv", correct: false, steps: [], totalMinutes: 81),
            ]
        )

        #expect(reveal.closestGuess?.guess == "ut")
    }

    @Test("Is the game's trip with the lowest total minutes")
    func game() {
        let game = Game(
            key: GameKey(network: .nl, number: 1),
            maxGuesses: 6,
            guesses: ["gvc", "ut"],
            trips: [
                GuessTrip(
                    guess: "gvc",
                    correct: false,
                    steps: [.ride(train: "IC", minutes: 30), .change(station: nil, minutes: 5)]
                ),
                GuessTrip(guess: "ut", correct: false, steps: [.ride(train: "IC", minutes: 34)]),
            ]
        )

        #expect(game.closestGuess?.guess == "ut")
    }

    @Test("Is nothing before the first guess or while the trips are not rebuilt")
    func none() {
        let key = GameKey(network: .nl, number: 1)

        #expect(Game(key: key, maxGuesses: 6).closestGuess == nil)
        #expect(Game(key: key, maxGuesses: 6, guesses: ["ut"], trips: nil).closestGuess == nil)
        #expect(Reveal(station: "asd", solved: false, guesses: []).closestGuess == nil)
    }
}
