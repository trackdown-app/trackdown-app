import Analytics
import Foundation
import GameCore
import Observation

/// Something the results sheet loads, with where it stands.
public enum Loadable<Value: Sendable & Hashable>: Sendable, Hashable {
    case loading
    case loaded(Value)
    case failed(PlayingProblem)

    /// The value, once loaded.
    public var value: Value? {
        guard case .loaded(let value) = self else { return nil }
        return value
    }
}

/// How a finished game went, as the results sheet says it.
public enum GameOutcome: Sendable, Hashable {
    /// "Tracked down in 5 of 6".
    case solved(guesses: Int, maxGuesses: Int)
    /// "Out of guesses."
    case missed
}

/// The guess whose trip to the mystery station was shortest: "Closest guess: Utrecht Centraal, 17 minutes away".
public struct ClosestGuess: Sendable, Hashable {
    public var station: String
    public var minutes: Int
}

/// The Solved and Missed sheet's state: the answer, the player's record and the text to share.
///
/// The game itself lives in the ``GameStore``; the answer comes from the reveal, asked for once the game is over.
@MainActor
@Observable
public final class ResultsModel {
    public let key: GameKey

    /// The mystery station and every guess's whole trip.
    public private(set) var reveal: Loadable<Reveal> = .loading
    /// The player's record at the game's network.
    public private(set) var statistics: Loadable<Statistics> = .loading

    @ObservationIgnored private let store: GameStore
    @ObservationIgnored private let service: any PuzzleService
    @ObservationIgnored private let locale: StationLocale
    @ObservationIgnored private let analytics: any AnalyticsClient
    /// Whether the game was today's puzzle when the sheet opened.
    @ObservationIgnored private let wasToday: Bool
    private var stations: [StationCode: Station] = [:]

    /// - Parameters:
    ///   - key: The finished game.
    ///   - store: Where the game is kept.
    ///   - service: Where the station list comes from.
    ///   - locale: The language of station names and of the shared text.
    public init(
        key: GameKey, store: GameStore, service: any PuzzleService, locale: StationLocale = .device,
        analytics: any AnalyticsClient = DisabledAnalytics()
    ) {
        self.key = key
        self.store = store
        self.service = service
        self.locale = locale
        self.analytics = analytics
        wasToday = store.today[key.network]?.number == key.number
    }

    public var game: Game? { store.games[key] }

    // MARK: Loading

    /// Loads the station names, the answer and the record side by side. Call from the view's `.task`, and again to
    /// retry what failed.
    public func load() async {
        async let names: Void = loadStations()
        async let answer: Void = loadReveal()
        async let record: Void = loadStatistics()
        _ = await (names, answer, record)
    }

    private func loadStations() async {
        guard stations.isEmpty else { return }
        // Best effort: without names the sheet shows station codes, as the playing screen does.
        guard let list = try? await service.stations(network: key.network, locale: locale) else { return }
        stations = Dictionary(list.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func loadReveal() async {
        guard reveal.value == nil else { return }
        reveal = .loading
        do {
            // Opened from the archive, a past game may not be open yet: replay it so the sheet knows how it went.
            if game == nil || game?.status == .restoring {
                try await store.openArchive(number: key.number, network: key.network)
            }
            reveal = .loaded(try await store.reveal(key))
        } catch is CancellationError {
            return
        } catch {
            reveal = .failed(PlayingProblem(error))
        }
    }

    private func loadStatistics() async {
        guard statistics.value == nil else { return }
        statistics = .loading
        do {
            statistics = .loaded(try await store.statistics(network: key.network))
        } catch is CancellationError {
            return
        } catch {
            statistics = .failed(PlayingProblem(error))
        }
    }

    // MARK: The result

    /// How the game went, once it is over.
    public var outcome: GameOutcome? {
        guard let game else { return nil }
        switch game.status {
        case .solved: return .solved(guesses: game.guesses.count, maxGuesses: game.maxGuesses)
        case .lost: return .missed
        case .playing, .restoring: return nil
        }
    }

    /// The mystery station's name, once revealed.
    public var stationName: String? {
        reveal.value.map { name(of: $0.station) }
    }

    /// On a missed game, the guess that came closest. `nil` on a solved game.
    public var closestGuess: ClosestGuess? {
        guard outcome == .missed, let trip = game?.closestGuess else { return nil }
        return ClosestGuess(station: name(of: trip.guess), minutes: trip.totalMinutes)
    }

    /// The "Guesses needed" chart: one bar per guess count, then Missed. The game on the sheet is highlighted.
    public var distribution: [DistributionBar] {
        guard let statistics = statistics.value else { return [] }
        let highlighted: DistributionBar.Bucket? =
            switch outcome {
            case .solved(let guesses, _): .guesses(guesses)
            case .missed: .missed
            case nil: nil
            }
        return DistributionBar.bars(for: statistics, highlighted: highlighted)
    }

    /// The text the Share button hands on, the same as the website's. `nil` until the game is over.
    public var shareText: String? {
        game.flatMap { ShareText.text(for: $0, language: locale) }
    }

    /// Records a completed share or copy, never the shared text or the revealed station.
    public func shareCompleted(method: AnalyticsEvent.ShareMethod, completed: Bool, error: (any Error)?) {
        guard completed, error == nil, let game, game.isOver else { return }
        analytics.capture(
            .resultShared(
                PuzzleEventProperties(network: key.network, puzzleNumber: key.number, archive: game.isArchive),
                method: method
            ))
    }

    /// When the next puzzle comes out, for the countdown.
    public var nextPuzzleAt: Date? {
        store.today[key.network]?.nextPuzzleAt
    }

    /// Whether the game on the sheet was today's when the sheet opened and a newer puzzle is today's now, so the sheet
    /// can make way for it. A past puzzle's sheet stays.
    public var hasNewerPuzzle: Bool {
        guard wasToday, let today = store.today[key.network] else { return false }
        return today.number > key.number
    }

    /// The countdown reached zero: loads the next puzzle, unless the rollover already did.
    public func countdownEnded() async {
        _ = try? await store.rolloverIfNeeded(network: key.network)
    }

    /// The display name of `code`, or the code itself while the station list is not loaded.
    public func name(of code: StationCode) -> String {
        stations[code]?.name ?? code.rawValue
    }
}
