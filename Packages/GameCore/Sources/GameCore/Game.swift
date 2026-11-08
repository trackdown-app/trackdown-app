/// One game of one puzzle: the guesses made and the trips they got back.
public struct Game: Sendable, Hashable, Identifiable {
    /// Where a game stands.
    public enum Status: Sendable, Hashable {
        /// Guesses are stored but their trips are not rebuilt yet, so it is not known whether the last one was
        /// right. Usually means the replay failed, for example offline.
        case restoring
        /// More guesses can be made.
        case playing
        /// The last guess was the mystery station.
        case solved
        /// Every guess is used and none was right.
        case lost
    }

    public var key: GameKey
    /// How many guesses a game allows, from the API.
    public var maxGuesses: Int
    /// Whether the game was started from the archive rather than on its own day.
    public var isArchive: Bool
    /// Every guess so far, in order.
    public var guesses: [StationCode]
    /// One trip per guess, in the order of ``guesses``. `nil` until the stored guesses are replayed.
    public var trips: [GuessTrip]?

    public var id: GameKey { key }

    public init(
        key: GameKey,
        maxGuesses: Int,
        isArchive: Bool = false,
        guesses: [StationCode] = [],
        trips: [GuessTrip]? = []
    ) {
        self.key = key
        self.maxGuesses = maxGuesses
        self.isArchive = isArchive
        self.guesses = guesses
        self.trips = trips
    }

    public var status: Status {
        guard let trips else { return .restoring }
        if trips.last?.correct == true { return .solved }
        return guesses.count >= maxGuesses ? .lost : .playing
    }

    /// Whether the game is solved or out of guesses.
    public var isOver: Bool { status == .solved || status == .lost }

    /// Guesses left before the game is lost.
    public var guessesLeft: Int { max(0, maxGuesses - guesses.count) }

    /// What is kept on the device for this game, with its outcome once it is over.
    public var stored: StoredGame {
        let outcome: StoredGame.Outcome? =
            switch status {
            case .solved: .won
            case .lost: .lost
            case .playing, .restoring: nil
            }
        return StoredGame(guesses: guesses, archive: isArchive, outcome: outcome)
    }
}

/// The trip from one guessed station to the mystery station, as the game shows it.
public struct GuessTrip: Sendable, Hashable {
    public var guess: StationCode
    public var correct: Bool
    public var steps: [TripStep]

    public init(guess: StationCode, correct: Bool, steps: [TripStep]) {
        self.guess = guess
        self.correct = correct
        self.steps = steps
    }

    /// The whole trip's length: every ride and change.
    public var totalMinutes: Int { steps.reduce(0) { $0 + $1.minutes } }
}

extension GuessResult {
    /// Every guess's trip, the earlier ones first. Earlier guesses were all wrong, or the game would have ended.
    public var trips: [GuessTrip] {
        earlierTrips.map { GuessTrip(guess: $0.guess, correct: false, steps: $0.steps) }
            + [GuessTrip(guess: guess, correct: correct, steps: steps)]
    }
}
