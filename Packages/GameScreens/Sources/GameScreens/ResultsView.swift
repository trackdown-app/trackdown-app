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
                RecordView(model: model)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
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

/// The record: the statistics row and the "Guesses needed" chart, or why they did not load.
private struct RecordView: View {
    let model: ResultsModel

    var body: some View {
        switch model.statistics {
        case .loading:
            VStack(alignment: .leading, spacing: 18) {
                StatisticsRow(statistics: Self.placeholder)
                DistributionChart(bars: Self.placeholderBars)
            }
            .redacted(reason: .placeholder)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text("Loading your record", bundle: .module, comment: "VoiceOver label while the statistics load."))
        case .failed:
            RetryRow(
                message: Text(
                    "Your record didn't load.", bundle: .module,
                    comment: "On the results sheet when the statistics could not be loaded.")
            ) {
                Task { await model.load() }
            }
        case .loaded(let statistics):
            VStack(alignment: .leading, spacing: 18) {
                StatisticsRow(statistics: statistics)
                DistributionChart(bars: model.distribution)
            }
        }
    }

    private static let placeholder = Statistics(
        played: 36, won: 33, winPercent: 92, currentStreak: 7, bestStreak: 12,
        distribution: [0, 2, 6, 11, 9, 5], missed: 3, today: nil)

    private static let placeholderBars = [0, 2, 6, 11, 9, 5].enumerated().map {
        DistributionBar(
            bucket: .guesses($0.offset + 1), count: $0.element, fraction: Double($0.element) / 11, isHighlighted: false)
    }
}

/// Played, Won, Streak and Best, between two hairlines. Two rows of two at large text sizes.
private struct StatisticsRow: View {
    let statistics: Statistics

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(items, id: \.id) { item in
                    StatisticView(item: item)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
                GridRow {
                    StatisticView(item: items[0])
                    StatisticView(item: items[1])
                }
                GridRow {
                    StatisticView(item: items[2])
                    StatisticView(item: items[3])
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var items: [StatisticItem] {
        [
            StatisticItem(
                id: 0, title: Text("Played", bundle: .module, comment: "Statistic: games finished."),
                value: statistics.played.formatted()),
            StatisticItem(
                id: 1, title: Text("Won", bundle: .module, comment: "Statistic: the share of games solved."),
                value: (Double(statistics.winPercent) / 100).formatted(.percent)),
            StatisticItem(
                id: 2,
                title: Text("Streak", bundle: .module, comment: "Statistic: puzzles solved on their day in a row."),
                value: statistics.currentStreak.formatted()),
            StatisticItem(
                id: 3, title: Text("Best", bundle: .module, comment: "Statistic: the longest streak so far."),
                value: statistics.bestStreak.formatted()),
        ]
    }
}

private struct StatisticItem {
    let id: Int
    let title: Text
    let value: String
}

private struct StatisticView: View {
    let item: StatisticItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            item.title
                .font(TrackdownFont.caption)
                .foregroundStyle(TrackdownColor.muted)
            Text(verbatim: item.value)
                .font(TrackdownFont.statistic)
                .foregroundStyle(TrackdownColor.ink)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "Guesses needed": a bar per guess count and Missed, the game on the sheet in the first line color.
private struct DistributionChart: View {
    let bars: [DistributionBar]

    @ScaledMetric(relativeTo: .footnote) private var labelWidth: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Guesses needed", bundle: .module, comment: "Heading of the chart of how many guesses each game took.")
                .font(TrackdownFont.subheadlineEmphasized)
                .foregroundStyle(TrackdownColor.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 2)
            ForEach(bars) { bar in
                DistributionRow(bar: bar, labelWidth: labelWidth)
            }
        }
    }
}

private struct DistributionRow: View {
    let bar: DistributionBar
    let labelWidth: CGFloat

    @State private var width: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            label
                .font(TrackdownFont.footnote)
                .foregroundStyle(TrackdownColor.muted)
                .frame(minWidth: labelWidth, alignment: .leading)
            HStack(spacing: 8) {
                Capsule()
                    .fill(bar.isHighlighted ? TrackdownColor.line1 : TrackdownColor.empty)
                    // The fullest bar takes 80 % of the row, leaving room for its count; an empty one keeps a stub.
                    .frame(width: max(width * 0.8 * bar.fraction, width * 0.02), height: 8)
                Text(bar.count, format: .number)
                    .font(TrackdownFont.captionEmphasized)
                    .monospacedDigit()
                    .foregroundStyle(TrackdownColor.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: {
                width = $0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text(bar.count, format: .number))
        .accessibilityAddTraits(bar.isHighlighted ? .isSelected : [])
    }

    @ViewBuilder
    private var label: some View {
        switch bar.bucket {
        case .guesses(let count): Text(count, format: .number)
        case .missed: missed
        }
    }

    private var missed: Text {
        Text("Missed", bundle: .module, comment: "Chart row of the games that ran out of guesses.")
    }

    private var accessibilityLabel: Text {
        switch bar.bucket {
        case .guesses(1):
            Text("1 guess", bundle: .module, comment: "VoiceOver label of the chart row of games solved in one guess.")
        case .guesses(let count):
            Text(
                "\(count) guesses", bundle: .module,
                comment: "VoiceOver label of a chart row of games solved in this many guesses, more than one.")
        case .missed:
            missed
        }
    }
}

/// Share, Older puzzles on the Missed sheet, and the countdown to the next station.
private struct ResultsActions: View {
    let model: ResultsModel
    let onOlderPuzzles: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
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
        let text = model.shareText ?? ""
        ShareLink(item: text) {
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
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(TrackdownColor.ink)
        .foregroundStyle(TrackdownColor.background)
        .disabled(model.shareText == nil)
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

/// A short message with a Try again button.
private struct RetryRow: View {
    let message: Text
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            message
                .font(TrackdownFont.callout)
                .foregroundStyle(TrackdownColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: retry) {
                Text("Try again", bundle: .module, comment: "Retries loading the puzzle.")
                    .font(TrackdownFont.headline)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .foregroundStyle(TrackdownColor.ink)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(TrackdownColor.rule)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
