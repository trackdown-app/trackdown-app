/// A player's record at one network, worked out from the games kept on the device.
///
/// A port of the website's `computeStatistics` (`src/lib/game/statistics.ts`, `docs/statistics.md`): the same
/// numbers from the same games.
public struct Statistics: Sendable, Hashable {
    /// How today's game went, once it is over.
    public enum TodayResult: Sendable, Hashable {
        /// Solved in this many guesses.
        case solved(guesses: Int)
        /// Ran out of guesses.
        case missed
    }

    /// One finished game, as the record counts it.
    public struct FinishedGame: Sendable, Hashable {
        /// Whether the game was solved or ran out of guesses.
        public var solved: Bool
        /// How many guesses it took.
        public var guessCount: Int
        /// Whether a guess was made in the archive, after the puzzle's own day. Such a game counts as played,
        /// but not for the streak.
        public var archive: Bool

        public init(solved: Bool, guessCount: Int, archive: Bool) {
            self.solved = solved
            self.guessCount = guessCount
            self.archive = archive
        }

        /// `game` once it is over; `nil` while it is still on or its trips are not rebuilt yet.
        public init?(_ game: Game) {
            switch game.status {
            case .solved: self.init(solved: true, guessCount: game.guesses.count, archive: game.isArchive)
            case .lost: self.init(solved: false, guessCount: game.guesses.count, archive: game.isArchive)
            case .playing, .restoring: return nil
            }
        }
    }

    /// Games finished, solved or missed, at any puzzle.
    public var played: Int
    /// Games solved.
    public var won: Int
    /// ``won`` of ``played``, rounded to a whole percent; 0 before the first game.
    public var winPercent: Int
    /// Puzzles solved on their own day in a row, up to today's or yesterday's.
    public var currentStreak: Int
    /// The longest such run so far, the current one included.
    public var bestStreak: Int
    /// How many games were solved in 1, 2, … `maxGuesses` guesses: index 0 is 1 guess.
    public var distribution: [Int]
    /// How many games ran out of guesses.
    public var missed: Int
    /// How today's game went, or `nil` while it is on or not started. The distribution highlights it.
    public var today: TodayResult?

    public init(
        played: Int,
        won: Int,
        winPercent: Int,
        currentStreak: Int,
        bestStreak: Int,
        distribution: [Int],
        missed: Int,
        today: TodayResult?
    ) {
        self.played = played
        self.won = won
        self.winPercent = winPercent
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.distribution = distribution
        self.missed = missed
        self.today = today
    }

    /// The record over `puzzles`, every puzzle up to today's (the archive, in any order; the latest by date is
    /// today's), from `games`, the finished game at each puzzle number.
    ///
    /// The streak counts puzzles solved on their own day in Europe/Amsterdam. A puzzle missed, not played, or
    /// played in the archive (after its day) breaks it. Today's puzzle breaks nothing while it is still to play,
    /// so the streak runs on from yesterday until the day is over. A day without a puzzle is not a day to miss.
    public init(puzzles: [ArchivedPuzzle], games: [Int: FinishedGame], maxGuesses: Int) {
        var distribution = Array(repeating: 0, count: max(0, maxGuesses))
        var won = 0
        var missed = 0
        var run = 0
        var bestStreak = 0
        var today: TodayResult?

        // Same day, any order: keep the archive's order, as the website's stable sort does.
        let sorted = puzzles.enumerated()
            .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)

        for (index, puzzle) in sorted.enumerated() {
            let game = games[puzzle.number]
            let isToday = index == sorted.count - 1

            if let game {
                if game.solved {
                    won += 1
                    let slot = game.guessCount - 1
                    if distribution.indices.contains(slot) {
                        distribution[slot] += 1
                    }
                } else {
                    missed += 1
                }
                if isToday {
                    today = game.solved ? .solved(guesses: game.guessCount) : .missed
                }
            }

            if let game, game.solved, !game.archive {
                run += 1
                bestStreak = max(bestStreak, run)
            } else if !(isToday && game == nil) {
                run = 0
            }
        }

        let played = won + missed
        self.init(
            played: played,
            won: won,
            winPercent: played == 0 ? 0 : Int((Double(won) / Double(played) * 100).rounded()),
            currentStreak: run,
            bestStreak: bestStreak,
            distribution: distribution,
            missed: missed,
            today: today
        )
    }

    /// The record over `puzzles` from `games`, the game at each puzzle number. Games still on, or whose trips are
    /// not rebuilt yet, count as not played.
    public init(puzzles: [ArchivedPuzzle], games: [Int: Game], maxGuesses: Int) {
        self.init(puzzles: puzzles, games: games.compactMapValues(FinishedGame.init), maxGuesses: maxGuesses)
    }
}

extension Game {
    /// The guess whose trip to the mystery station is shortest: the lowest ``GuessTrip/totalMinutes``, the earliest
    /// on a tie. `nil` before the first guess or while the trips are not rebuilt. The Missed screen's "Closest guess".
    public var closestGuess: GuessTrip? {
        trips?.min { $0.totalMinutes < $1.totalMinutes }
    }
}

extension Reveal {
    /// The guess whose trip to the mystery station is shortest: the lowest ``RevealedGuess/totalMinutes``, the
    /// earliest on a tie. `nil` without guesses. The Missed screen's "Closest guess".
    public var closestGuess: RevealedGuess? {
        guesses.min { $0.totalMinutes < $1.totalMinutes }
    }
}
