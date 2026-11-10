#if DEBUG
    import Analytics
    import DesignSystem
    import GameCore
    import GameScreens
    import SwiftUI

    /// Offline, isolated screen fixtures for accessibility UI tests. Never included in release builds.
    struct AccessibilityFixtureView: View {
        let screen: String
        @State private var fixture: AccessibilityFixture?
        @Environment(\.dynamicTypeSize) private var systemTypeSize

        private var typeSize: DynamicTypeSize {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-accessibility-dynamic-type") { return systemTypeSize }
            return arguments.contains("UICTContentSizeCategoryAccessibilityXXXL") ? .accessibility5 : .large
        }

        var body: some View {
            Group {
                if let fixture {
                    NavigationStack {
                        content(fixture)
                            .accessibilityIdentifier("accessibility-fixture-\(screen)")
                    }
                } else {
                    ProgressView()
                }
            }
            .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-accessibility-dark") ? .dark : .light)
            .dynamicTypeSize(typeSize)
            .task {
                do {
                    let value = AccessibilityFixture()
                    try await value.store.loadToday(network: .nl)
                    let guesses: [StationCode] =
                        screen == "solved"
                        ? ["mt", "ut"]
                        : screen == "missed" ? ["mt", "asd", "gn", "hlm", "zl", "asdz"] : ["mt"]
                    for guess in guesses { try await value.store.submit(guess, to: value.key) }
                    fixture = value
                } catch {
                    assertionFailure("Accessibility fixture failed: \(error)")
                }
            }
        }

        @ViewBuilder
        private func content(_ fixture: AccessibilityFixture) -> some View {
            switch screen {
            case "solved", "missed":
                ResultsView(
                    model: fixture.results,
                    onOlderPuzzles: {}, onNextPuzzle: {})
            case "archive":
                ArchiveView(
                    model: fixture.archive,
                    onSelect: { _ in }, onChooseNetwork: {})
            case "networks":
                ChooseNetworkView(
                    model: fixture.networks, onChoose: { _ in },
                    onNotify: { _ in })
            case "privacy":
                PrivacyView(settings: fixture.settings)
            case "how-to-play":
                HowToPlaySheet(settings: fixture.settings, network: .nl)
            case "consent":
                TrackdownColor.background.consentPrompt(isPresented: true) { _ in }
            default:
                PlayingView(
                    model: fixture.playing,
                    onNavigate: { _ in })
            }
        }
    }

    private final class AccessibilityFixture {
        let service = AccessibilityPuzzleService()
        let key = GameKey(network: .nl, number: 142)
        let store: GameStore
        let settings: AnalyticsSettings
        // Keep model identity stable when their observable store changes during loading.
        lazy var results = ResultsModel(key: key, store: store, service: service)
        lazy var archive = ArchiveModel(network: .nl, store: store, service: service)
        lazy var networks = ChooseNetworkModel(current: .nl, store: store)
        lazy var playing = PlayingModel(network: .nl, store: store, service: service)

        init() {
            store = GameStore(service: service, storage: AccessibilityStorage())
            let defaults = UserDefaults(suiteName: "AccessibilityFixtures")!
            defaults.removePersistentDomain(forName: "AccessibilityFixtures")
            settings = AnalyticsSettings(
                configuration: AnalyticsConfiguration(projectToken: "", host: URL(string: "https://trackdown.nl")!),
                defaults: defaults)
        }
    }

    private nonisolated struct AccessibilityStorage: GameStorage {
        func load(_ key: GameKey) -> StoredGame? { nil }
        func save(_ game: StoredGame, for key: GameKey) throws {}
    }

    private nonisolated struct AccessibilityPuzzleService: PuzzleService {
        let puzzle = Puzzle(
            network: .nl, number: 142, date: PuzzleDate(year: 2026, month: 11, day: 6), maxGuesses: 6,
            nextPuzzleAt: Date.now.addingTimeInterval(3600))
        let names: [(StationCode, String)] = [
            ("mt", "Maastricht"), ("ut", "Utrecht Centraal"), ("asd", "Amsterdam Centraal"),
            ("gn", "Groningen"), ("hlm", "Haarlem"), ("zl", "Zwolle"), ("asdz", "Amsterdam Zuid"),
        ]

        func today(network: Network) async throws -> Puzzle { puzzle }
        func stations(network: Network, locale: StationLocale) async throws -> [Station] {
            names.map { Station(code: $0.0, name: $0.1, province: "Netherlands") }
        }
        func puzzles(network: Network) async throws -> [ArchivedPuzzle] {
            [
                ArchivedPuzzle(number: 141, date: PuzzleDate(year: 2026, month: 11, day: 5)),
                ArchivedPuzzle(number: 142, date: puzzle.date),
            ]
        }
        func guess(_ guess: StationCode, earlierGuesses: [StationCode], puzzle: Int, network: Network) async throws
            -> GuessResult
        {
            GuessResult(
                guess: guess, correct: guess == "ut", steps: steps(guess), totalMinutes: guess == "ut" ? 0 : 145,
                earlierTrips: earlierGuesses.map { EarlierTrip(guess: $0, steps: steps($0)) })
        }
        func reveal(guesses: [StationCode], puzzle: Int, network: Network) async throws -> Reveal {
            Reveal(
                station: "ut", solved: guesses.last == "ut",
                guesses: guesses.map {
                    RevealedGuess(guess: $0, correct: $0 == "ut", steps: steps($0), totalMinutes: $0 == "ut" ? 0 : 145)
                })
        }
        private func steps(_ guess: StationCode) -> [TripStep] {
            guess == "ut"
                ? []
                : [
                    .ride(train: "IC", minutes: 122), .change(station: nil, minutes: 6),
                    .ride(train: "SPR", minutes: 17),
                ]
        }
    }
#endif
