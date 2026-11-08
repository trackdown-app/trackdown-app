/// Everything the game asks the server, in domain types.
///
/// Every method throws a ``PuzzleServiceError``, or `CancellationError` when its task is cancelled.
public protocol PuzzleService: Sendable {
    /// Today's puzzle, without its answer.
    func today(network: Network) async throws -> Puzzle

    /// Every station a player can guess, sorted by name, with names in `locale`.
    func stations(network: Network, locale: StationLocale) async throws -> [Station]

    /// Every puzzle up to today's, oldest first.
    func puzzles(network: Network) async throws -> [ArchivedPuzzle]

    /// Submits `guess` for puzzle `puzzle`, which may be any puzzle up to today's.
    ///
    /// - Parameter earlierGuesses: Every guess made on this puzzle before `guess`, in order.
    func guess(
        _ guess: StationCode,
        earlierGuesses: [StationCode],
        puzzle: Int,
        network: Network
    ) async throws -> GuessResult

    /// The mystery station of puzzle `puzzle` and every guess's whole trip.
    ///
    /// Call only once the game is over (solved, or out of guesses); the server answers
    /// ``PuzzleServiceError/gameNotOver`` otherwise.
    func reveal(guesses: [StationCode], puzzle: Int, network: Network) async throws -> Reveal
}

extension PuzzleService {
    /// Every station a player can guess, with names in the device's language.
    public func stations(network: Network) async throws -> [Station] {
        try await stations(network: network, locale: .device)
    }
}

/// Why a ``PuzzleService`` call failed.
public enum PuzzleServiceError: Error, Sendable, Hashable {
    /// The request did not match the API's schema (`invalid_input`), such as an unknown station code.
    case invalidInput
    /// The server does not accept the app's client key or version (`unknown_client`). Usually means the app
    /// must be updated.
    case unknownClient
    /// A reveal before the game is over (`game_not_over`).
    case gameNotOver
    /// The puzzle does not exist or is after today's (`not_found`).
    case notFound
    /// Too many guesses or reveals (`rate_limited`). Try again after `retryAfter`.
    case rateLimited(retryAfter: Duration)
    /// Something went wrong on the server (`internal_error`).
    case internalError
    /// The device could not reach the server.
    case offline
    /// Any other answer: an undocumented status, an unknown error code or a body that does not decode.
    case unexpectedResponse
}
