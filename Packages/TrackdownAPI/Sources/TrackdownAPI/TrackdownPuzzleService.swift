import Foundation
import GameCore
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// The ``PuzzleService`` the app uses: calls trackdown.nl `/api/v1` through the generated ``Client`` and hands
/// back `GameCore` types only.
///
/// After a `rate_limited` answer it does not call the server for a guess or reveal again until the
/// `Retry-After` time has passed; it throws ``PuzzleServiceError/rateLimited(retryAfter:)`` with the time left.
public actor TrackdownPuzzleService: PuzzleService {
    private let client: any APIProtocol
    private let stationCache: StationCache?
    private let now: @Sendable () -> Date
    private var rateLimitedUntil: Date?

    /// - Parameters:
    ///   - client: The API, usually a ``Client``.
    ///   - stationCache: Where station lists are kept for a day. `nil` fetches them every time.
    ///   - now: The current time, for the station cache and `Retry-After`.
    public init(
        client: any APIProtocol,
        stationCache: StationCache? = .caches,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.stationCache = stationCache
        self.now = now
    }

    /// A service on a ``Client`` that sends the app's headers.
    public init(
        apiConfiguration: APIConfiguration,
        transport: any ClientTransport = URLSessionTransport(),
        stationCache: StationCache? = .caches
    ) {
        self.init(client: Client(apiConfiguration: apiConfiguration, transport: transport), stationCache: stationCache)
    }

    public func today(network: Network) async throws -> Puzzle {
        let output = try await call { try await client.getTodayPuzzle(path: .init(network: .init(network))) }
        switch output {
        case .ok(let response): return try Puzzle(response.body.json)
        case .badRequest(let response): throw error(try response.body.json)
        case .unauthorized(let response): throw error(try response.body.json)
        case .forbidden(let response): throw error(try response.body.json)
        case .notFound(let response): throw error(try response.body.json)
        case .internalServerError(let response): throw error(try response.body.json)
        case .undocumented(let status, let payload): throw undocumented(status: status, payload: payload)
        }
    }

    public func stations(network: Network, locale: StationLocale) async throws -> [Station] {
        let cached = stationCache?.entry(network: network, locale: locale)
        if let cached, stationCache?.isFresh(cached, now: now()) == true {
            return cached.stations
        }

        do {
            let stations = try await fetchStations(network: network, locale: locale)
            stationCache?.store(.init(fetchedAt: now(), stations: stations), network: network, locale: locale)
            return stations
        } catch PuzzleServiceError.offline {
            // An old list beats none: stations rarely change.
            guard let cached else { throw PuzzleServiceError.offline }
            return cached.stations
        }
    }

    public func puzzles(network: Network) async throws -> [ArchivedPuzzle] {
        let output = try await call { try await client.getPuzzleArchive(path: .init(network: .init(network))) }
        switch output {
        case .ok(let response): return try response.body.json.puzzles.map(ArchivedPuzzle.init)
        case .badRequest(let response): throw error(try response.body.json)
        case .unauthorized(let response): throw error(try response.body.json)
        case .forbidden(let response): throw error(try response.body.json)
        case .internalServerError(let response): throw error(try response.body.json)
        case .undocumented(let status, let payload): throw undocumented(status: status, payload: payload)
        }
    }

    public func guess(
        _ guess: StationCode,
        earlierGuesses: [StationCode],
        puzzle: Int,
        network: Network
    ) async throws -> GuessResult {
        try checkRateLimit()
        let output = try await call {
            try await client.submitGuess(
                path: .init(network: .init(network), number: puzzle),
                body: .json(.init(guess: guess.rawValue, earlierGuesses: earlierGuesses.map(\.rawValue)))
            )
        }
        switch output {
        case .ok(let response): return GuessResult(try response.body.json)
        case .badRequest(let response): throw error(try response.body.json)
        case .unauthorized(let response): throw error(try response.body.json)
        case .forbidden(let response): throw error(try response.body.json)
        case .notFound(let response): throw error(try response.body.json)
        case .tooManyRequests(let response):
            throw error(try response.body.json, retryAfterSeconds: response.headers.retryAfter)
        case .internalServerError(let response): throw error(try response.body.json)
        case .undocumented(let status, let payload): throw undocumented(status: status, payload: payload)
        }
    }

    public func reveal(guesses: [StationCode], puzzle: Int, network: Network) async throws -> Reveal {
        try checkRateLimit()
        let output = try await call {
            try await client.revealAnswer(
                path: .init(network: .init(network), number: puzzle),
                body: .json(.init(guesses: guesses.map(\.rawValue)))
            )
        }
        switch output {
        case .ok(let response): return Reveal(try response.body.json)
        case .badRequest(let response): throw error(try response.body.json)
        case .unauthorized(let response): throw error(try response.body.json)
        case .forbidden(let response): throw error(try response.body.json)
        case .notFound(let response): throw error(try response.body.json)
        case .tooManyRequests(let response):
            throw error(try response.body.json, retryAfterSeconds: response.headers.retryAfter)
        case .internalServerError(let response): throw error(try response.body.json)
        case .undocumented(let status, let payload): throw undocumented(status: status, payload: payload)
        }
    }

    // MARK: - Calls

    private func fetchStations(network: Network, locale: StationLocale) async throws -> [Station] {
        let output = try await call {
            try await client.getStations(
                path: .init(network: .init(network)),
                query: .init(locale: .init(rawValue: locale.rawValue))
            )
        }
        switch output {
        case .ok(let response): return try response.body.json.stations.map(Station.init)
        case .badRequest(let response): throw error(try response.body.json)
        case .unauthorized(let response): throw error(try response.body.json)
        case .forbidden(let response): throw error(try response.body.json)
        case .internalServerError(let response): throw error(try response.body.json)
        case .undocumented(let status, let payload): throw undocumented(status: status, payload: payload)
        }
    }

    /// Runs one client call and turns what the client throws (transport failures, bodies that do not decode)
    /// into a ``PuzzleServiceError`` or `CancellationError`.
    private func call<Output>(_ operation: () async throws -> Output) async throws -> Output {
        do {
            return try await operation()
        } catch {
            throw mapClientError(error)
        }
    }

    private func checkRateLimit() throws {
        guard let rateLimitedUntil else { return }
        let left = rateLimitedUntil.timeIntervalSince(now())
        guard left > 0 else {
            self.rateLimitedUntil = nil
            return
        }
        throw PuzzleServiceError.rateLimited(retryAfter: .seconds(Int(left.rounded(.up))))
    }

    // MARK: - Errors

    /// The error for an `ApiError` body. The body's code wins over the status, which only says the same less
    /// precisely.
    private func error(_ body: Components.Schemas.ApiError, retryAfterSeconds: Int? = nil) -> PuzzleServiceError {
        switch body.error.code {
        case .invalidInput: return .invalidInput
        case .unknownClient: return .unknownClient
        case .gameNotOver: return .gameNotOver
        case .notFound: return .notFound
        case .rateLimited: return rateLimited(retryAfterSeconds: retryAfterSeconds ?? 0)
        case .internalError: return .internalError
        case .crossOrigin, .methodNotAllowed: return .unexpectedResponse
        }
    }

    private func undocumented(status: Int, payload: UndocumentedPayload) -> PuzzleServiceError {
        error(status: status, headerFields: payload.headerFields)
    }

    /// The error for a status alone, when the body is missing or does not decode.
    private func error(status: Int, headerFields: HTTPFields) -> PuzzleServiceError {
        switch status {
        case 400: return .invalidInput
        case 401: return .unknownClient
        case 404: return .notFound
        case 429: return rateLimited(retryAfterSeconds: headerFields[.retryAfter].flatMap { Int($0) } ?? 0)
        case 500...599: return .internalError
        default: return .unexpectedResponse
        }
    }

    private func rateLimited(retryAfterSeconds: Int) -> PuzzleServiceError {
        let seconds = max(retryAfterSeconds, 0)
        rateLimitedUntil = now().addingTimeInterval(TimeInterval(seconds))
        return .rateLimited(retryAfter: .seconds(seconds))
    }

    private func mapClientError(_ error: any Error) -> any Error {
        let clientError = error as? ClientError
        let cause = clientError?.underlyingError ?? error

        if cause is CancellationError { return cause }
        if let urlError = cause as? URLError {
            if urlError.code == .cancelled { return CancellationError() }
            if Self.offlineCodes.contains(urlError.code) { return PuzzleServiceError.offline }
        }
        if let response = clientError?.response, response.status.kind != .successful {
            return self.error(status: response.status.code, headerFields: response.headerFields)
        }
        return PuzzleServiceError.unexpectedResponse
    }

    /// URL loading failures that mean the server could not be reached.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff, .callIsActive, .secureConnectionFailed,
    ]
}

// MARK: - Generated types to domain types

extension Components.Schemas.NetworkId {
    fileprivate init(_ network: Network) {
        switch network {
        case .nl: self = .nl
        case .gb: self = .gb
        }
    }
}

extension Network {
    fileprivate init(_ network: Components.Schemas.NetworkId) {
        switch network {
        case .nl: self = .nl
        case .gb: self = .gb
        }
    }
}

extension PuzzleDate {
    fileprivate init(server string: String) throws {
        guard let date = PuzzleDate(iso8601: string) else { throw PuzzleServiceError.unexpectedResponse }
        self = date
    }
}

extension Puzzle {
    fileprivate init(_ puzzle: Components.Schemas.TodayPuzzle) throws {
        self.init(
            network: Network(puzzle.network),
            number: puzzle.number,
            date: try PuzzleDate(server: puzzle.date),
            maxGuesses: puzzle.maxGuesses,
            nextPuzzleAt: puzzle.nextPuzzleAt
        )
    }
}

extension ArchivedPuzzle {
    fileprivate init(_ puzzle: Components.Schemas.ArchivedPuzzle) throws {
        self.init(number: puzzle.number, date: try PuzzleDate(server: puzzle.date))
    }
}

extension Station {
    fileprivate init(_ station: Components.Schemas.Station) {
        self.init(code: StationCode(station.code), name: station.name, province: station.province)
    }
}

extension TripStep {
    fileprivate init(_ ride: Components.Schemas.Ride) {
        self = .ride(train: TrainType(rawValue: ride.train.rawValue), minutes: ride.minutes)
    }

    fileprivate init(_ change: Components.Schemas.HiddenChange) {
        self = .change(station: change.station.map { StationCode($0) }, minutes: change.minutes)
    }

    fileprivate init(_ change: Components.Schemas.Change) {
        self = .change(station: StationCode(change.station), minutes: change.minutes)
    }

    fileprivate init(_ step: Components.Schemas.GuessResult.StepsPayloadPayload) {
        switch step {
        case .ride(let ride): self.init(ride)
        case .change(let change): self.init(change)
        }
    }

    fileprivate init(_ step: Components.Schemas.EarlierTrip.StepsPayloadPayload) {
        switch step {
        case .ride(let ride): self.init(ride)
        case .change(let change): self.init(change)
        }
    }

    fileprivate init(_ step: Components.Schemas.RevealedGuess.StepsPayloadPayload) {
        switch step {
        case .ride(let ride): self.init(ride)
        case .change(let change): self.init(change)
        }
    }
}

extension GuessResult {
    fileprivate init(_ result: Components.Schemas.GuessResult) {
        self.init(
            guess: StationCode(result.guess),
            correct: result.correct,
            steps: result.steps.map(TripStep.init),
            totalMinutes: result.totalMinutes,
            earlierTrips: result.earlierTrips.map {
                EarlierTrip(guess: StationCode($0.guess), steps: $0.steps.map(TripStep.init))
            }
        )
    }
}

extension Reveal {
    fileprivate init(_ reveal: Components.Schemas.Reveal) {
        self.init(
            station: StationCode(reveal.station),
            solved: reveal.solved,
            guesses: reveal.guesses.map {
                RevealedGuess(
                    guess: StationCode($0.guess),
                    correct: $0.correct,
                    steps: $0.steps.map(TripStep.init),
                    totalMinutes: $0.totalMinutes
                )
            }
        )
    }
}
