import DesignSystem
import SwiftUI

/// The top of the playing screen: the puzzle's day, the progress dots and "Puzzle 142, guess 5 of 6".
struct PlayingHeader: View {
    /// The day, such as "Friday 6 November". `nil` while unknown.
    let title: String?
    let puzzle: Int
    let currentGuess: Int
    let maxGuesses: Int
    /// Guesses made so far.
    let used: Int
    /// Whether more guesses can be made, so the next dot is the current one.
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(verbatim: title)
                    .font(TrackdownFont.largeTitle)
                    .foregroundStyle(TrackdownColor.ink)
                    .accessibilityAddTraits(.isHeader)
            } else {
                EmptyView()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    dots
                    progressText
                }
                VStack(alignment: .leading, spacing: 8) {
                    dots
                    progressText
                }
            }
        }
    }

    private var dots: some View {
        ProgressDots(count: maxGuesses, used: used, isPlaying: isPlaying)
    }

    private var progressText: some View {
        Text(
            "Puzzle \(puzzle), guess \(currentGuess) of \(maxGuesses)", bundle: .module,
            comment: "Under the day on the playing screen: the puzzle number and which guess is being made."
        )
        .font(TrackdownFont.subheadline)
        .monospacedDigit()
        .foregroundStyle(TrackdownColor.muted)
    }
}

/// One dot per guess on a line: filled for guesses used, a dark ring for the current guess, a light ring for the rest.
/// The line is inked up to the current guess.
struct ProgressDots: View {
    let count: Int
    let used: Int
    let isPlaying: Bool

    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 10
    @ScaledMetric(relativeTo: .subheadline) private var spacing: CGFloat = 10

    /// The dot the inked line runs to.
    private var current: Int { isPlaying ? used : max(used - 1, 0) }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                dot(at: index)
                    .frame(width: size, height: size)
            }
        }
        .background(alignment: .leading) {
            ZStack(alignment: .leading) {
                Capsule().fill(TrackdownColor.empty)
                Capsule()
                    .fill(TrackdownColor.ink)
                    .frame(width: CGFloat(current) * (size + spacing))
            }
            .frame(height: 2)
            .padding(.horizontal, size / 2 - 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dot(at index: Int) -> some View {
        if index < used {
            Circle().fill(TrackdownColor.ink)
        } else {
            Circle()
                .strokeBorder(index == used && isPlaying ? TrackdownColor.ink : TrackdownColor.empty, lineWidth: 2.5)
                .background { Circle().fill(TrackdownColor.background) }
        }
    }
}
