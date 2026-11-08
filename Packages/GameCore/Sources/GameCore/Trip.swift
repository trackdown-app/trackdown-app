/// A train category, such as `IC` (Intercity) or `SPR` (Sprinter).
///
/// A string rather than a closed enum, so the game keeps working when the server adds a category.
public struct TrainType: RawRepresentable, Sendable, Hashable, Codable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

/// One step of a trip from a guessed station to the mystery station.
public enum TripStep: Sendable, Hashable {
    /// A ride on one train.
    case ride(train: TrainType, minutes: Int)
    /// A change of trains. `station` is `nil` while the game hides where the change happens; after the reveal
    /// every change names its station.
    case change(station: StationCode?, minutes: Int)

    public var minutes: Int {
        switch self {
        case .ride(_, let minutes), .change(_, let minutes): minutes
        }
    }
}

/// The answer to one guess: the trip from the guessed station to the mystery station.
public struct GuessResult: Sendable, Hashable {
    public var guess: StationCode
    public var correct: Bool
    public var steps: [TripStep]
    public var totalMinutes: Int
    /// The trips of the earlier guesses, as the server sees them now.
    public var earlierTrips: [EarlierTrip]

    public init(guess: StationCode, correct: Bool, steps: [TripStep], totalMinutes: Int, earlierTrips: [EarlierTrip]) {
        self.guess = guess
        self.correct = correct
        self.steps = steps
        self.totalMinutes = totalMinutes
        self.earlierTrips = earlierTrips
    }
}

/// The trip of an earlier guess, returned with every new guess.
public struct EarlierTrip: Sendable, Hashable {
    public var guess: StationCode
    public var steps: [TripStep]

    public init(guess: StationCode, steps: [TripStep]) {
        self.guess = guess
        self.steps = steps
    }
}

/// The answer once the game is over: the mystery station and every guess's whole trip.
public struct Reveal: Sendable, Hashable {
    public var station: StationCode
    public var solved: Bool
    public var guesses: [RevealedGuess]

    public init(station: StationCode, solved: Bool, guesses: [RevealedGuess]) {
        self.station = station
        self.solved = solved
        self.guesses = guesses
    }
}

/// One guess in a reveal, with every change's station named.
public struct RevealedGuess: Sendable, Hashable {
    public var guess: StationCode
    public var correct: Bool
    public var steps: [TripStep]
    public var totalMinutes: Int

    public init(guess: StationCode, correct: Bool, steps: [TripStep], totalMinutes: Int) {
        self.guess = guess
        self.correct = correct
        self.steps = steps
        self.totalMinutes = totalMinutes
    }
}
