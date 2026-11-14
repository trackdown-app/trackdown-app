import DesignSystem
import SwiftUI

/// The board before the first guess: a line that runs like a train trip from the mystery-station column down to the
/// guess field, and beside it where to start.
///
/// The route reads as a trip in reverse: the second train leaves the mystery-station bar, a "?" ring marks the change,
/// and the first train turns down at a rail-map angle and ends in an arrowhead over the field's magnifying glass. It
/// draws itself in once, in that order, when the board appears; with Reduce Motion on it is simply there.
///
/// With a route, put the prompt right above the guess bar, its leading edge in line with the bar's, and let it fill the
/// height left over: the arrowhead lands at its bottom edge. Without one, as when the guess field is on the other side
/// of a fold, only the text shows.
struct FirstGuessPrompt: View {
    /// Whether to draw the route down to the guess field.
    let showsRoute: Bool

    @State private var isDrawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                "Start from a station you know", bundle: .module,
                comment: "Heading on the board before the first guess, beside a line that points to the guess field."
            )
            .font(TrackdownFont.title2)
            .foregroundStyle(TrackdownColor.ink)
            Text(
                "Each guess draws the fastest train journey from your station to the mystery station.",
                bundle: .module,
                comment: "Under the heading on the board before the first guess."
            )
            .font(TrackdownFont.callout)
            .foregroundStyle(TrackdownColor.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .padding(.leading, showsRoute ? RouteGeometry.textInset : 0)
        .padding(.top, showsRoute ? RouteGeometry.textTop : 24)
        .padding(.bottom, showsRoute ? RouteGeometry.textBottom : 0)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background {
            if showsRoute {
                route
            } else {
                EmptyView()
            }
        }
        .onAppear { isDrawn = true }
    }

    private var route: some View {
        GeometryReader { proxy in
            let geometry = RouteGeometry(size: proxy.size)
            ZStack(alignment: .topLeading) {
                geometry.secondTrain
                    .trim(from: 0, to: isDrawn ? 1 : 0)
                    .stroke(TrackdownColor.line2, style: RouteGeometry.lineStyle)
                    .animation(animation(.easeInOut(duration: 0.5)), value: isDrawn)
                geometry.firstTrain
                    .trim(from: 0, to: isDrawn ? 1 : 0)
                    .stroke(TrackdownColor.line1, style: RouteGeometry.lineStyle)
                    .animation(animation(.easeInOut(duration: 0.9).delay(0.55)), value: isDrawn)
                Capsule()
                    .fill(TrackdownColor.ink)
                    .frame(width: RouteGeometry.barWidth, height: RouteGeometry.barHeight)
                    .position(geometry.bar)
                ChangeRing()
                    .scaleEffect(isDrawn ? 1 : 0.4)
                    .opacity(isDrawn ? 1 : 0)
                    .animation(animation(.snappy(duration: 0.3).delay(0.4)), value: isDrawn)
                    .position(geometry.ring)
                Arrowhead()
                    .stroke(TrackdownColor.line1, style: RouteGeometry.lineStyle)
                    .frame(width: RouteGeometry.arrowheadSize.width, height: RouteGeometry.arrowheadSize.height)
                    .scaleEffect(isDrawn ? 1 : 0.4, anchor: .bottom)
                    .opacity(isDrawn ? 1 : 0)
                    .animation(animation(.snappy(duration: 0.3).delay(1.4)), value: isDrawn)
                    .position(geometry.arrowhead)
            }
        }
        .accessibilityHidden(true)
    }

    /// The draw-in animation, or none with Reduce Motion on.
    private func animation(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// Where the route's pieces sit in the prompt.
private struct RouteGeometry {
    static let lineStyle = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
    static let barWidth: CGFloat = 9
    static let barHeight: CGFloat = 44
    static let arrowheadSize = CGSize(width: 24, height: 14)
    /// From the top of the prompt to the horizontal run, through the middle of the bar.
    static let lineY: CGFloat = 12 + barHeight / 2
    /// The vertical run, in line with the guess field's magnifying glass.
    static let stemX: CGFloat = GuessBar.iconCenter
    /// How far the diagonal runs across, and so down, at 45 degrees.
    static let diagonal: CGFloat = 90
    /// The text sits clear of the vertical run, below the diagonal.
    static let textInset: CGFloat = stemX + 26
    static let textTop: CGFloat = lineY + diagonal + 24
    static let textBottom: CGFloat = 28

    let size: CGSize

    private var bendX: CGFloat { Self.stemX + Self.diagonal }
    /// The bottom of the vertical run, where the arrowhead's tip is.
    private var tipY: CGFloat { size.height - 2 }

    var bar: CGPoint { CGPoint(x: size.width - Self.barWidth / 2, y: Self.lineY) }
    var ring: CGPoint { CGPoint(x: max(bendX + 48, size.width * 0.64), y: Self.lineY) }
    var arrowhead: CGPoint { CGPoint(x: Self.stemX, y: tipY - Self.arrowheadSize.height / 2) }

    /// From the bar to the change.
    var secondTrain: Path {
        Path { path in
            path.move(to: bar)
            path.addLine(to: ring)
        }
    }

    /// From the change to the guess field: left, diagonally down, then straight down.
    var firstTrain: Path {
        Path { path in
            path.move(to: ring)
            path.addLine(to: CGPoint(x: bendX, y: Self.lineY))
            path.addLine(to: CGPoint(x: Self.stemX, y: Self.lineY + Self.diagonal))
            path.addLine(to: CGPoint(x: Self.stemX, y: tipY))
        }
    }
}

/// A downward chevron, its tip at the bottom middle.
private struct Arrowhead: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
    }
}

/// The change ring with its "?", as on a trip whose change station is still hidden.
private struct ChangeRing: View {
    var body: some View {
        Circle()
            .strokeBorder(TrackdownColor.ink, lineWidth: 2.5)
            .background { Circle().fill(TrackdownColor.surface) }
            .overlay {
                Text(verbatim: "?")
                    .font(TrackdownFont.lineLabel)
                    .foregroundStyle(TrackdownColor.ink)
            }
            .frame(width: 22, height: 22)
    }
}

#Preview("Above the guess bar") {
    TrackdownFont.register()
    return VStack(spacing: 10) {
        FirstGuessPrompt(showsRoute: true)
        GuessBar(text: .constant(""), suggestions: [], selection: .constant(nil)) {}
    }
    .padding(16)
    .background { TrackdownColor.background.ignoresSafeArea() }
}

#Preview("Text only") {
    TrackdownFont.register()
    return FirstGuessPrompt(showsRoute: false)
        .padding(16)
        .background { TrackdownColor.background.ignoresSafeArea() }
}
