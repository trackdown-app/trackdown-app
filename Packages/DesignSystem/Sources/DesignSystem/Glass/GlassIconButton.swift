import SwiftUI

/// The icons of the circular glass buttons, with the label VoiceOver reads for each.
public enum TrackdownIcon: Sendable, CaseIterable {
    case back
    case close
    case howToPlay
    case statistics
    case archive

    /// The SF Symbol drawn in the button.
    public var systemImage: String {
        switch self {
        case .back: "chevron.backward"
        case .close: "xmark"
        case .howToPlay: "questionmark.circle"
        case .statistics: "chart.bar"
        case .archive: "calendar"
        }
    }

    /// The button's name, for VoiceOver and for toolbar overflow menus.
    public var title: Text {
        switch self {
        case .back: Text("Back", bundle: .module)
        case .close: Text("Close", bundle: .module)
        case .howToPlay: Text("How to play", bundle: .module)
        case .statistics: Text("Statistics", bundle: .module)
        case .archive: Text("Archive", bundle: .module)
        }
    }

    /// The icon with its title, for a `Button` in a toolbar, where the system draws the glass.
    public var label: some View {
        Label {
            title
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

/// A 44 pt circular glass button with one icon: back, close, how to play, statistics or archive.
///
/// Use it where the system does not draw glass for you, such as a header floating over content or the top of a sheet.
/// In a toolbar, use a plain `Button { } label: { icon.label }` instead: toolbar items already get glass.
///
/// Inside a ``GlassIconButtonGroup`` the buttons share one capsule instead of drawing their own circles.
public struct GlassIconButton: View {
    private let icon: TrackdownIcon
    private let action: () -> Void

    @Environment(\.isInGlassIconButtonGroup) private var isGrouped
    private let size: CGFloat = 44

    public init(_ icon: TrackdownIcon, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            icon.label
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(TrackdownColor.ink)
        .glassEffect(isGrouped ? .identity : .regular.interactive(), in: .circle)
    }
}

/// Icon buttons that sit together in one glass capsule, like the archive, how to play and statistics buttons at the
/// top of the playing screen.
public struct GlassIconButtonGroup<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 2)
        .environment(\.isInGlassIconButtonGroup, true)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

extension EnvironmentValues {
    /// Whether a ``GlassIconButton`` is inside a ``GlassIconButtonGroup``, which draws the glass for it.
    @Entry var isInGlassIconButtonGroup = false
}

#Preview("Icon buttons") {
    GlassPreviewBackdrop {
        HStack {
            GlassIconButton(.back) {}
            Spacer()
            GlassIconButtonGroup {
                GlassIconButton(.archive) {}
                GlassIconButton(.howToPlay) {}
                GlassIconButton(.statistics) {}
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview("Icon buttons, dark") {
    GlassPreviewBackdrop {
        HStack {
            GlassIconButton(.close) {}
            Spacer()
            GlassIconButtonGroup {
                GlassIconButton(.archive) {}
                GlassIconButton(.howToPlay) {}
                GlassIconButton(.statistics) {}
            }
        }
        .padding(.horizontal, 16)
    }
    .preferredColorScheme(.dark)
}
