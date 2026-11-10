import DesignSystem
import GameCore
import SwiftUI

/// The Solved and Missed sheet: how the game went and the mystery station, the player's record, the "Guesses needed"
/// chart, Share, and the countdown to the next station.
///
/// Present it in a ``SwiftUI/View/glassSheet(item:detents:content:)`` at a detent that leaves the playing screen
/// showing above it: once the game is revealed, the playing screen names every change and the mystery station.
public struct ResultsView: View {
    private let model: ResultsModel
    private let onOlderPuzzles: () -> Void
    private let onNextPuzzle: () -> Void

    /// - Parameters:
    ///   - model: The finished game.
    ///   - onOlderPuzzles: Opens the archive, from the Missed sheet's Older puzzles button.
    ///   - onNextPuzzle: Makes way for the next puzzle, once it is today's.
    public init(
        model: ResultsModel,
        onOlderPuzzles: @escaping () -> Void,
        onNextPuzzle: @escaping () -> Void
    ) {
        self.model = model
        self.onOlderPuzzles = onOlderPuzzles
        self.onNextPuzzle = onNextPuzzle
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GlassSheetHeader {
                        ResultsHeadline(outcome: model.outcome, station: model.stationName, isFailed: isRevealFailed)
                    }
                    if case .failed = model.reveal {
                        RetryRow(
                            message: Text(
                                "The answer didn't load.", bundle: .module,
                                comment: "On the results sheet when the mystery station could not be loaded.")
                        ) {
                            Task { await model.load() }
                        }
                    } else {
                        EmptyView()
                    }
                    if let closest = model.closestGuess {
                        ClosestGuessText(closest: closest)
                    } else {
                        EmptyView()
                    }
                    RecordView(statistics: model.statistics, bars: model.distribution) {
                        Task { await model.load() }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .clipped()
            ResultsActions(model: model, onOlderPuzzles: onOlderPuzzles)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .task { await model.load() }
        .onChange(of: model.hasNewerPuzzle, initial: true) { _, isNewer in
            if isNewer { onNextPuzzle() }
        }
    }

    private var isRevealFailed: Bool {
        if case .failed = model.reveal { true } else { false }
    }
}

/// "Tracked down in 5 of 6" or "Out of guesses. The station was", and the mystery station's name under it.
private struct ResultsHeadline: View {
    let outcome: GameOutcome?
    let station: String?
    let isFailed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                switch outcome {
                case .solved(let guesses, let maxGuesses):
                    Text(
                        "Tracked down in \(guesses) of \(maxGuesses)", bundle: .module,
                        comment: "Above the mystery station on the Solved sheet: how many guesses it took, of how many."
                    )
                case .missed:
                    Text(
                        "Out of guesses. The station was", bundle: .module,
                        comment:
                            "Above the mystery station on the Missed sheet. The station's name follows on its own line."
                    )
                case nil:
                    EmptyView()
                }
            }
            .font(TrackdownFont.callout)
            .foregroundStyle(TrackdownColor.muted)

            if let station {
                Text(verbatim: station)
                    .font(TrackdownFont.display)
                    .foregroundStyle(TrackdownColor.ink)
            } else if !isFailed {
                // Holds the station's place while the reveal answers.
                Text(verbatim: "Amersfoort Centraal")
                    .font(TrackdownFont.display)
                    .redacted(reason: .placeholder)
                    .accessibilityLabel(
                        Text(
                            "Loading the answer", bundle: .module,
                            comment: "VoiceOver label while the mystery station loads."))
            } else {
                EmptyView()
            }
        }
    }
}

/// "Closest guess: Utrecht Centraal, 17 minutes away."
private struct ClosestGuessText: View {
    let closest: ClosestGuess

    var body: some View {
        let distance = Duration.seconds(closest.minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .wide))
        Text(
            "Closest guess: **\(closest.station)**, \(distance) away.", bundle: .module,
            comment:
                "On the Missed sheet. The arguments are the guessed station closest to the answer and its trip time, such as \"17 minutes\"."
        )
        .font(TrackdownFont.callout)
        .foregroundStyle(TrackdownColor.ink)
        .padding(.top, -4)
    }
}

/// Share, Older puzzles on the Missed sheet, and the countdown to the next station.
private struct ResultsActions: View {
    let model: ResultsModel
    let onOlderPuzzles: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
    }

    #if os(iOS)
        @State private var share: ResultShare?
    #endif

    var body: some View {
        VStack(spacing: 12) {
            GlassEffectContainer(spacing: 10) {
                layout {
                    shareButton
                    if model.outcome == .missed {
                        Button(action: onOlderPuzzles) {
                            Text(
                                "Older puzzles", bundle: .module, comment: "Missed sheet button that opens the archive."
                            )
                            .font(TrackdownFont.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .foregroundStyle(TrackdownColor.ink)
                    } else {
                        EmptyView()
                    }
                }
            }
            if let nextPuzzleAt = model.nextPuzzleAt {
                Countdown(until: nextPuzzleAt) {
                    Task { await model.countdownEnded() }
                }
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        Group {
            #if os(iOS)
                Button {
                    if let text = model.shareText { share = ResultShare(text: text) }
                } label: {
                    shareLabel
                }
                .sheet(item: $share) { share in
                    ResultShareSheet(text: share.text, onComplete: model.shareCompleted)
                }
            #else
                // The macOS build exists only for host tests; the app uses the completion-aware iOS sheet.
                ShareLink(item: model.shareText ?? "") { shareLabel }
            #endif
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(TrackdownColor.ink)
        .foregroundStyle(TrackdownColor.background)
        .disabled(model.shareText == nil)
    }

    private var shareLabel: some View {
        Label {
            if model.outcome == .missed {
                Text("Share", bundle: .module, comment: "Missed sheet button that shares the result.")
            } else {
                Text("Share result", bundle: .module, comment: "Solved sheet button that shares the result.")
            }
        } icon: {
            Image(systemName: "square.and.arrow.up")
        }
        .font(TrackdownFont.headline)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

/// "Next station in 13:42:08", counting down every second. Calls `onEnd` once it reaches zero.
private struct Countdown: View {
    let until: Date
    let onEnd: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let clock = Self.remaining(until: until, now: context.date)
                .formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2)))
            Text(
                "Next station in \(Text(verbatim: clock).font(TrackdownFont.subheadlineEmphasized).foregroundStyle(TrackdownColor.ink))",
                bundle: .module,
                comment: "Under the Share button: the time until the next puzzle, such as 13:42:08."
            )
            .font(TrackdownFont.subheadline)
            .monospacedDigit()
            .foregroundStyle(TrackdownColor.muted)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .task(id: until) {
            let wait = until.timeIntervalSinceNow
            if wait > 0 {
                do { try await Task.sleep(for: .seconds(wait)) } catch { return }
            }
            onEnd()
        }
    }

    /// Whole seconds left, rounded up, never below zero. The hours do not wrap: the day the clocks go back is 25 hours.
    static func remaining(until: Date, now: Date) -> Duration {
        .seconds(max(0, Int(until.timeIntervalSince(now).rounded(.up))))
    }
}
