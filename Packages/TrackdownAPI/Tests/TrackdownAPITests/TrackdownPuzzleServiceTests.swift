import Foundation
import GameCore
import HTTPTypes
import Testing
import TrackdownAPI

struct TrackdownPuzzleServiceTests {
    // MARK: - today

    @Test("today(network:) fetches today's puzzle and ignores unknown fields")
    func today() async throws {
        let transport = MockTransport(
            .json(
                """
                {"network":"nl","number":42,"date":"2026-11-08","maxGuesses":6,
                 "nextPuzzleAt":"2026-11-08T23:00:00Z","hint":"new field","extra":{"nested":true}}
                """
            )
        )

        let puzzle = try await TrackdownPuzzleService.test(transport).today(network: .nl)

        #expect(
            puzzle
                == Puzzle(
                    network: .nl,
                    number: 42,
                    date: PuzzleDate(year: 2026, month: 11, day: 8),
                    maxGuesses: 6,
                    nextPuzzleAt: Date(timeIntervalSince1970: 1_794_178_800)
                )
        )
        let sent = try #require(await transport.sent.first)
        #expect(sent.request.method == .get)
        #expect(sent.request.path == "/api/v1/nl/puzzles/today")
        #expect(sent.request.headerFields[.trackdownClientKey] == "test-key")
    }

    @Test("today(network:) uses the network in the path")
    func todayNetwork() async throws {
        let transport = MockTransport(
            .json(
                #"{"network":"gb","number":1,"date":"2026-11-08","maxGuesses":6,"nextPuzzleAt":"2026-11-09T00:00:00Z"}"#
            )
        )

        let puzzle = try await TrackdownPuzzleService.test(transport).today(network: .gb)

        #expect(puzzle.network == .gb)
        #expect(await transport.sent.first?.request.path == "/api/v1/gb/puzzles/today")
    }

    @Test("A date that is not YYYY-MM-DD is an unexpected response")
    func todayBadDate() async throws {
        let transport = MockTransport(
            .json(#"{"network":"nl","number":1,"date":"8 Nov","maxGuesses":6,"nextPuzzleAt":"2026-11-09T00:00:00Z"}"#)
        )

        await #expect(throws: PuzzleServiceError.unexpectedResponse) {
            try await TrackdownPuzzleService.test(transport).today(network: .nl)
        }
    }

    // MARK: - puzzles

    @Test("puzzles(network:) fetches the archive, oldest first as the server sends it")
    func puzzles() async throws {
        let transport = MockTransport(
            .json(
                #"""
                {"network":"nl","puzzles":[{"number":1,"date":"2026-11-06"},{"number":2,"date":"2026-11-07","x":1},
                {"number":3,"date":"2026-11-08"}]}
                """#
            )
        )

        let puzzles = try await TrackdownPuzzleService.test(transport).puzzles(network: .nl)

        #expect(
            puzzles == [
                ArchivedPuzzle(number: 1, date: PuzzleDate(year: 2026, month: 11, day: 6)),
                ArchivedPuzzle(number: 2, date: PuzzleDate(year: 2026, month: 11, day: 7)),
                ArchivedPuzzle(number: 3, date: PuzzleDate(year: 2026, month: 11, day: 8)),
            ]
        )
        let sent = try #require(await transport.sent.first)
        #expect(sent.request.method == .get)
        #expect(sent.request.path == "/api/v1/nl/puzzles")
    }

    // MARK: - guess

    @Test("guess(...) posts the guess and every earlier guess, for any puzzle number", arguments: [1, 17, 42])
    func guess(number: Int) async throws {
        let transport = MockTransport(
            .json(
                """
                {"network":"nl","number":\(number),"guess":"ut","correct":false,"totalMinutes":52,"future":1,
                 "steps":[{"kind":"ride","train":"IC","minutes":27},{"kind":"change","station":null,"minutes":5},
                          {"kind":"ride","train":"SPR","minutes":20}],
                 "earlierTrips":[{"guess":"asd","steps":[{"kind":"ride","train":"ICD","minutes":40}]},
                                 {"guess":"gvc","steps":[{"kind":"change","station":"ledn","minutes":3}]}]}
                """
            )
        )

        let result = try await TrackdownPuzzleService.test(transport)
            .guess("ut", earlierGuesses: ["asd", "gvc"], puzzle: number, network: .nl)

        #expect(
            result
                == GuessResult(
                    guess: "ut",
                    correct: false,
                    steps: [
                        .ride(train: "IC", minutes: 27),
                        .change(station: nil, minutes: 5),
                        .ride(train: "SPR", minutes: 20),
                    ],
                    totalMinutes: 52,
                    earlierTrips: [
                        EarlierTrip(guess: "asd", steps: [.ride(train: "ICD", minutes: 40)]),
                        EarlierTrip(guess: "gvc", steps: [.change(station: "ledn", minutes: 3)]),
                    ]
                )
        )
        let sent = try #require(await transport.sent.first)
        #expect(sent.request.method == .post)
        #expect(sent.request.path == "/api/v1/nl/puzzles/\(number)/guesses")
        #expect(try jsonObject(sent.body) == ["guess": "ut", "earlierGuesses": ["asd", "gvc"]])
    }

    @Test("guess(...) reports a correct guess")
    func correctGuess() async throws {
        let transport = MockTransport(
            .json(
                #"{"network":"nl","number":3,"guess":"ut","correct":true,"steps":[],"totalMinutes":0,"earlierTrips":[]}"#
            )
        )

        let result = try await TrackdownPuzzleService.test(transport)
            .guess("ut", earlierGuesses: [], puzzle: 3, network: .nl)

        #expect(result.correct)
        #expect(try jsonObject(await transport.sent.first?.body) == ["guess": "ut", "earlierGuesses": [String]()])
    }

    // MARK: - reveal

    @Test("reveal(...) posts every guess, for any puzzle number, and names every change", arguments: [1, 42])
    func reveal(number: Int) async throws {
        let transport = MockTransport(
            .json(
                """
                {"network":"nl","number":\(number),"station":"ut","solved":true,"new":"field",
                 "guesses":[{"guess":"asd","correct":false,"totalMinutes":31,
                             "steps":[{"kind":"ride","train":"IC","minutes":26},{"kind":"change","station":"ut","minutes":5}]},
                            {"guess":"ut","correct":true,"totalMinutes":0,"steps":[]}]}
                """
            )
        )

        let reveal = try await TrackdownPuzzleService.test(transport)
            .reveal(guesses: ["asd", "ut"], puzzle: number, network: .nl)

        #expect(
            reveal
                == Reveal(
                    station: "ut",
                    solved: true,
                    guesses: [
                        RevealedGuess(
                            guess: "asd",
                            correct: false,
                            steps: [.ride(train: "IC", minutes: 26), .change(station: "ut", minutes: 5)],
                            totalMinutes: 31
                        ),
                        RevealedGuess(guess: "ut", correct: true, steps: [], totalMinutes: 0),
                    ]
                )
        )
        let sent = try #require(await transport.sent.first)
        #expect(sent.request.method == .post)
        #expect(sent.request.path == "/api/v1/nl/puzzles/\(number)/reveal")
        #expect(try jsonObject(sent.body) == ["guesses": ["asd", "ut"]])
    }
}

// MARK: - stations

@Suite("stations(network:locale:)")
struct StationsTests {
    private static let stationsJSON = #"""
        {"network":"nl","locale":"en","stations":[
          {"code":"asd","name":"Amsterdam Central","province":"North Holland","lat":52.3},
          {"code":"ut","name":"Utrecht Central","province":"Utrecht"}]}
        """#

    private static let stations = [
        Station(code: "asd", name: "Amsterdam Central", province: "North Holland"),
        Station(code: "ut", name: "Utrecht Central", province: "Utrecht"),
    ]

    private let cache: StationCache

    init() {
        cache = StationCache(
            directory: FileManager.default.temporaryDirectory.appending(path: "StationsTests-\(UUID().uuidString)")
        )
    }

    @Test("Fetches the stations in the locale asked for", arguments: StationLocale.allCases)
    func fetches(locale: StationLocale) async throws {
        let transport = MockTransport(.json(Self.stationsJSON))

        let stations = try await TrackdownPuzzleService.test(transport).stations(network: .nl, locale: locale)

        #expect(stations == Self.stations)
        let sent = try #require(await transport.sent.first)
        #expect(sent.request.method == .get)
        #expect(sent.request.path == "/api/v1/nl/stations?locale=\(locale.rawValue)")
    }

    @Test("Without a locale, asks in the device's language")
    func deviceLocale() async throws {
        let transport = MockTransport(.json(Self.stationsJSON))

        _ = try await TrackdownPuzzleService.test(transport).stations(network: .nl)

        let path = try #require(await transport.sent.first?.request.path)
        #expect(path == "/api/v1/nl/stations?locale=\(StationLocale.device.rawValue)")
    }

    @Test("Answers from the disk cache for a day, then fetches again")
    func cachesForADay() async throws {
        let clock = TestClock()
        let transport = MockTransport(.json(Self.stationsJSON), .json(Self.stationsJSON))
        let service = TrackdownPuzzleService.test(transport, clock: clock, stationCache: cache)

        _ = try await service.stations(network: .nl, locale: .en)
        clock.advance(by: 23 * 60 * 60)
        #expect(try await service.stations(network: .nl, locale: .en) == Self.stations)
        #expect(await transport.sent.count == 1)

        clock.advance(by: 60 * 60)
        _ = try await service.stations(network: .nl, locale: .en)
        #expect(await transport.sent.count == 2)
    }

    @Test("The cache survives a new service, as after an app relaunch")
    func cacheOnDisk() async throws {
        let clock = TestClock()
        _ = try await TrackdownPuzzleService.test(
            MockTransport(.json(Self.stationsJSON)), clock: clock, stationCache: cache
        )
        .stations(network: .nl, locale: .en)

        let transport = MockTransport()
        let stations = try await TrackdownPuzzleService.test(transport, clock: clock, stationCache: cache)
            .stations(network: .nl, locale: .en)

        #expect(stations == Self.stations)
        #expect(await transport.sent.isEmpty)
    }

    @Test("Keeps a separate cache per network and locale")
    func cachePerKey() async throws {
        let transport = MockTransport(.json(Self.stationsJSON), .json(Self.stationsJSON), .json(Self.stationsJSON))
        let service = TrackdownPuzzleService.test(transport, stationCache: cache)

        _ = try await service.stations(network: .nl, locale: .en)
        _ = try await service.stations(network: .nl, locale: .nl)
        _ = try await service.stations(network: .gb, locale: .en)

        #expect(
            await transport.sent.map(\.request.path) == [
                "/api/v1/nl/stations?locale=en", "/api/v1/nl/stations?locale=nl", "/api/v1/gb/stations?locale=en",
            ])
    }

    @Test("Offline, falls back to a stale cached list")
    func offlineStale() async throws {
        let clock = TestClock()
        let transport = MockTransport([
            .response(.json(Self.stationsJSON)), .failure(URLError(.notConnectedToInternet)),
        ])
        let service = TrackdownPuzzleService.test(transport, clock: clock, stationCache: cache)

        _ = try await service.stations(network: .nl, locale: .en)
        clock.advance(by: 2 * 24 * 60 * 60)

        #expect(try await service.stations(network: .nl, locale: .en) == Self.stations)
        #expect(await transport.sent.count == 2)
    }

    @Test("Offline without a cached list, throws offline")
    func offlineEmpty() async throws {
        let transport = MockTransport([.failure(URLError(.notConnectedToInternet))])

        await #expect(throws: PuzzleServiceError.offline) {
            try await TrackdownPuzzleService.test(transport, stationCache: cache).stations(network: .nl, locale: .en)
        }
    }

    @Test("Other errors are thrown even when a stale list is cached")
    func otherErrorsWithStaleCache() async throws {
        let clock = TestClock()
        let transport = MockTransport(.json(Self.stationsJSON), .apiError("unknown_client", status: 401))
        let service = TrackdownPuzzleService.test(transport, clock: clock, stationCache: cache)

        _ = try await service.stations(network: .nl, locale: .en)
        clock.advance(by: 2 * 24 * 60 * 60)

        await #expect(throws: PuzzleServiceError.unknownClient) {
            try await service.stations(network: .nl, locale: .en)
        }
    }
}

// MARK: - Errors

/// One service call, so every error case runs against every call.
enum ServiceCall: String, CaseIterable, CustomTestStringConvertible {
    case today
    case stations
    case puzzles
    case guess
    case reveal

    var testDescription: String { rawValue }

    func run(_ service: TrackdownPuzzleService) async throws {
        switch self {
        case .today: _ = try await service.today(network: .nl)
        case .stations: _ = try await service.stations(network: .nl, locale: .nl)
        case .puzzles: _ = try await service.puzzles(network: .nl)
        case .guess: _ = try await service.guess("ut", earlierGuesses: [], puzzle: 1, network: .nl)
        case .reveal: _ = try await service.reveal(guesses: ["ut"], puzzle: 1, network: .nl)
        }
    }
}

/// A server answer and the error it must become.
struct ErrorCase: Sendable, CustomTestStringConvertible {
    var name: String
    var response: MockResponse
    var expected: PuzzleServiceError

    var testDescription: String { name }

    static let all: [ErrorCase] = [
        ErrorCase(name: "invalid_input", response: .apiError("invalid_input", status: 400), expected: .invalidInput),
        ErrorCase(name: "unknown_client", response: .apiError("unknown_client", status: 401), expected: .unknownClient),
        ErrorCase(name: "game_not_over", response: .apiError("game_not_over", status: 403), expected: .gameNotOver),
        ErrorCase(name: "not_found", response: .apiError("not_found", status: 404), expected: .notFound),
        ErrorCase(
            name: "rate_limited with Retry-After",
            response: .apiError("rate_limited", status: 429, headers: [.retryAfter: "30"]),
            expected: .rateLimited(retryAfter: .seconds(30))
        ),
        ErrorCase(name: "internal_error", response: .apiError("internal_error", status: 500), expected: .internalError),
        ErrorCase(
            name: "cross_origin", response: .apiError("cross_origin", status: 403), expected: .unexpectedResponse),
        ErrorCase(
            name: "method_not_allowed",
            response: .apiError("method_not_allowed", status: 405),
            expected: .unexpectedResponse
        ),
        ErrorCase(
            name: "unknown error code falls back on the status", response: .apiError("new_code", status: 404),
            expected: .notFound),
        ErrorCase(name: "502 without a body", response: MockResponse(status: 502), expected: .internalError),
        ErrorCase(name: "undocumented 418", response: .json("{}", status: 418), expected: .unexpectedResponse),
        ErrorCase(name: "200 that does not decode", response: .json(#"{"nope":true}"#), expected: .unexpectedResponse),
    ]
}

@Suite("Errors")
struct PuzzleServiceErrorTests {
    @Test("Every call maps every server error", arguments: ServiceCall.allCases, ErrorCase.all)
    func mapsErrors(call: ServiceCall, errorCase: ErrorCase) async throws {
        let service = TrackdownPuzzleService.test(MockTransport(errorCase.response))

        await #expect(throws: errorCase.expected) {
            try await call.run(service)
        }
    }

    @Test(
        "Every call reports unreachable servers as offline",
        arguments: ServiceCall.allCases,
        [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost]
    )
    func offline(call: ServiceCall, code: URLError.Code) async throws {
        let service = TrackdownPuzzleService.test(MockTransport([.failure(URLError(code))]))

        await #expect(throws: PuzzleServiceError.offline) {
            try await call.run(service)
        }
    }

    @Test("Every call reports a cancelled request as CancellationError", arguments: ServiceCall.allCases)
    func cancelled(call: ServiceCall) async throws {
        let service = TrackdownPuzzleService.test(MockTransport([.failure(URLError(.cancelled))]))

        await #expect(throws: CancellationError.self) {
            try await call.run(service)
        }
    }

    @Test("After rate_limited, guess and reveal wait out Retry-After without calling the server")
    func honoursRetryAfter() async throws {
        let clock = TestClock()
        let transport = MockTransport(
            .apiError("rate_limited", status: 429, headers: [.retryAfter: "30"]),
            .json(
                #"{"network":"nl","number":1,"guess":"ut","correct":true,"steps":[],"totalMinutes":0,"earlierTrips":[]}"#
            )
        )
        let service = TrackdownPuzzleService.test(transport, clock: clock)

        await #expect(throws: PuzzleServiceError.rateLimited(retryAfter: .seconds(30))) {
            try await ServiceCall.guess.run(service)
        }

        clock.advance(by: 10.5)
        await #expect(throws: PuzzleServiceError.rateLimited(retryAfter: .seconds(20))) {
            try await ServiceCall.reveal.run(service)
        }
        await #expect(throws: PuzzleServiceError.rateLimited(retryAfter: .seconds(20))) {
            try await ServiceCall.guess.run(service)
        }
        #expect(await transport.sent.count == 1)

        clock.advance(by: 20)
        try await ServiceCall.guess.run(service)
        #expect(await transport.sent.count == 2)
    }
}
