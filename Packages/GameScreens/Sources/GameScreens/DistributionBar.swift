import GameCore

/// One bar of the "Guesses needed" chart.
public struct DistributionBar: Sendable, Hashable, Identifiable {
    public enum Bucket: Sendable, Hashable {
        /// Solved in this many guesses.
        case guesses(Int)
        /// Ran out of guesses.
        case missed
    }

    public var bucket: Bucket
    /// How many games fell in this bucket.
    public var count: Int
    /// `count` over the fullest bucket, from 0 to 1.
    public var fraction: Double
    /// Whether the chart marks this bar: the game on the Solved or Missed sheet, or today's game on the
    /// Statistics sheet.
    public var isHighlighted: Bool

    public var id: Bucket { bucket }

    /// The chart of `statistics`: one bar per guess count, then Missed, each measured against the fullest.
    ///
    /// - Parameter highlighted: The bucket to mark, if any.
    public static func bars(for statistics: Statistics, highlighted: Bucket?) -> [DistributionBar] {
        let counts =
            statistics.distribution.enumerated().map { (Bucket.guesses($0.offset + 1), $0.element) }
            + [(.missed, statistics.missed)]
        let fullest = max(counts.map(\.1).max() ?? 0, 1)
        return counts.map { bucket, count in
            DistributionBar(
                bucket: bucket,
                count: count,
                fraction: Double(count) / Double(fullest),
                isHighlighted: bucket == highlighted
            )
        }
    }
}

extension Statistics.TodayResult {
    /// The chart bucket today's game fell in.
    var bucket: DistributionBar.Bucket {
        switch self {
        case .solved(let guesses): .guesses(guesses)
        case .missed: .missed
        }
    }
}
