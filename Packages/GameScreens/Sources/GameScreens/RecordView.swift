import DesignSystem
import GameCore
import SwiftUI

/// The player's record: the statistics row and the "Guesses needed" chart, or why they did not load.
///
/// Shared by the Solved and Missed sheet and the Statistics sheet; each gives it its own heading.
struct RecordView: View {
    let statistics: Loadable<Statistics>
    /// The chart's bars, from ``DistributionBar/bars(for:highlighted:)``.
    let bars: [DistributionBar]
    /// Loads the record again after it failed.
    let retry: () -> Void

    var body: some View {
        switch statistics {
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
                    comment: "On the results and statistics sheets when the statistics could not be loaded."),
                retry: retry
            )
        case .loaded(let statistics):
            VStack(alignment: .leading, spacing: 18) {
                StatisticsRow(statistics: statistics)
                DistributionChart(bars: bars)
            }
        }
    }

    private static let placeholder = Statistics(
        played: 36, won: 33, winPercent: 92, currentStreak: 7, bestStreak: 12,
        distribution: [0, 2, 6, 11, 9, 5], missed: 3, today: nil)

    private static let placeholderBars = DistributionBar.bars(for: placeholder, highlighted: nil)
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

/// "Guesses needed": a bar per guess count and Missed, the highlighted one in the first line color.
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

/// A short message with a Try again button.
struct RetryRow: View {
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
