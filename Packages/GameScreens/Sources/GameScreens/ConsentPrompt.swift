import Analytics
import DesignSystem
import SwiftUI

extension View {
    /// Asks once whether the app may share anonymous usage data: a sheet as tall as its content that only an answer
    /// closes. Present it while the choice is unanswered; `onChoose` gets `.allowed` or `.declined`.
    ///
    /// A wide display, such as the iPhone Duo inner display, shows a card over the dimmed screen instead. Held like a
    /// book, the card sits at the bottom of the trailing side, clear of the fold, where the prompt will be as the device
    /// closes.
    public func consentPrompt(isPresented: Bool, onChoose: @escaping (AnalyticsConsent) -> Void) -> some View {
        modifier(ConsentPromptPresentation(isPresented: isPresented, onChoose: onChoose))
    }

    /// Confirms the answer to the consent prompt in a glass toast above the guess bar, with a link to Privacy
    /// settings. The toast clears `consent` after a few seconds.
    public func consentToast(_ consent: Binding<AnalyticsConsent?>, onSettings: @escaping () -> Void) -> some View {
        overlay(alignment: .bottom) {
            if let choice = consent.wrappedValue {
                VStack {
                    Spacer(minLength: 0)
                    ConsentToast(consent: choice, onSettings: onSettings)
                }
                .padding(.horizontal, 16)
                // Clears the guess bar, as on the design canvas.
                .padding(.bottom, 72)
                .reservedContent()
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .task {
                    try? await Task.sleep(for: .seconds(8))
                    guard !Task.isCancelled else { return }
                    consent.wrappedValue = nil
                }
            } else {
                EmptyView()
            }
        }
        .trackdownAnimation(value: consent.wrappedValue)
    }
}

/// The consent prompt: a sheet on a narrow display, a card on a wide one.
private struct ConsentPromptPresentation: ViewModifier {
    let isPresented: Bool
    let onChoose: (AnalyticsConsent) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCard: Bool { horizontalSizeClass == .regular }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented && isCard {
                    ConsentCard(onChoose: onChoose)
                        .transition(.opacity)
                } else {
                    EmptyView()
                }
            }
            .trackdownAnimation(value: isPresented && isCard)
            // An answer changes `isPresented`; nothing else dismisses the sheet, so the binding never writes back.
            .sheet(isPresented: .constant(isPresented && !isCard)) {
                ConsentPrompt(onChoose: onChoose)
                    .reservedContent()
                    .clipShape(ConcentricRectangle())
            }
    }
}

/// The consent prompt as a card over the dimmed screen, which takes every tap until the player answers.
///
/// The card stays one view across poses: flat, it is centred like a form sheet; held like a book, it sits at the bottom
/// of the trailing side; propped up like a tabletop, at the bottom of the lower half.
private struct ConsentCard: View {
    let onChoose: (AnalyticsConsent) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.black
                .opacity(colorScheme == .dark ? 0.5 : 0.22)
                .ignoresSafeArea()
                // Only an answer closes the prompt.
                .contentShape(.rect)
                .onTapGesture {}
                .accessibilityHidden(true)
            ConsentCardPlacement {
                ConsentPrompt(onChoose: onChoose, isCard: true)
                    .accessibilityAddTraits(.isModal)
            }
            .reservedContent(spreadsAcrossFold: true)
        }
    }
}

/// Places the card in the side of the fold it belongs on, or in the middle without one.
private struct ConsentCardPlacement<Card: View>: View {
    @ViewBuilder let card: Card

    @Environment(\.trackdownFoldSplit) private var split

    var body: some View {
        GeometryReader { geometry in
            // Both poses put the card on the second side: trailing in the book pose, bottom in the tabletop pose.
            let area = split?.second ?? CGRect(origin: .zero, size: geometry.size)
            card
                // A side of a book fits the card edge to edge; elsewhere it is as wide as a form sheet.
                .frame(maxWidth: split?.axis == .vertical ? .infinity : 540)
                .padding(16)
                .frame(width: area.width, height: area.height, alignment: split == nil ? .center : .bottom)
                .position(x: area.midX, y: area.midY)
        }
    }
}

/// The card's own glass, as tall as the prompt where there is room, like the sheet's detent. A sheet already has both.
private struct ConsentCardSurface: ViewModifier {
    let isCard: Bool
    let height: CGFloat

    func body(content: Content) -> some View {
        if isCard {
            let shape = ConcentricRectangle(corners: .concentric(minimum: .fixed(40)))
            content
                .frame(maxHeight: height)
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
        } else {
            content
        }
    }
}

/// The first-launch question: the mark, why the app asks, the privacy policy, and Allow or Don't allow.
struct ConsentPrompt: View {
    let onChoose: (AnalyticsConsent) -> Void
    /// Whether the prompt is a card on its own glass, rather than in a sheet.
    var isCard = false

    @State private var height: CGFloat = 440
    @State private var document: PrivacyDocument?
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TrackdownImage.mark
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 32)
                    .accessibilityHidden(true)
                Text(
                    "Help improve Trackdown?", bundle: .module, comment: "Title of the first-launch usage data prompt."
                )
                .font(TrackdownFont.title2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(2)
                .foregroundStyle(TrackdownColor.ink)
                .accessibilityAddTraits(.isHeader)
                Text(
                    "Trackdown is a hobby project without ads. With your OK, the app shares anonymous usage data with PostHog, like how many guesses a puzzle takes. Nothing is sold. Say no and the game works exactly the same.",
                    bundle: .module, comment: "Body of the first-launch usage data prompt."
                )
                .font(TrackdownFont.body)
                .foregroundStyle(TrackdownColor.muted)
                Button {
                    document = .privacyPolicy
                } label: {
                    Text("Privacy policy", bundle: .module, comment: "Opens the Trackdown privacy policy in Safari.")
                        .font(TrackdownFont.calloutEmphasized)
                        .underline()
                        .foregroundStyle(TrackdownColor.ink)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                choices
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            // A sheet adds the bottom safe area below this; a card has none.
            .padding(.bottom, isCard ? 24 : 4)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                height = $0
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .modifier(ConsentCardSurface(isCard: isCard, height: height))
        .presentationDetents([.height(height)])
        .interactiveDismissDisabled()
        #if os(iOS)
            .sheet(item: $document) { document in
                PrivacySafariView(url: document.url(for: locale))
                .ignoresSafeArea()
            }
        #endif
    }

    private var choices: some View {
        VStack(spacing: 10) {
            Button {
                onChoose(.allowed)
            } label: {
                Text("Allow", bundle: .module, comment: "Allows sharing anonymous usage data.")
                    .font(TrackdownFont.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(TrackdownColor.ink)
            .foregroundStyle(TrackdownColor.background)
            Button {
                onChoose(.declined)
            } label: {
                Text("Don't allow", bundle: .module, comment: "Declines sharing anonymous usage data.")
                    .font(TrackdownFont.headline)
                    .foregroundStyle(TrackdownColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background { Capsule().strokeBorder(TrackdownColor.ink, lineWidth: 2) }
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }
}

/// "Usage data on" or "off" after the prompt, with the way to change it.
struct ConsentToast: View {
    let consent: AnalyticsConsent
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(status)
                .font(TrackdownFont.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onSettings) {
                Text("Settings", bundle: .module, comment: "Link in the usage data toast that opens Privacy settings.")
                    .font(TrackdownFont.subheadlineEmphasized)
                    .underline()
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(TrackdownColor.ink)
        .padding(.leading, 18)
        .padding([.vertical, .trailing], 10)
        .glassEffect(.regular, in: ConcentricRectangle(corners: .concentric(minimum: .fixed(26))))
        .onAppear {
            AccessibilityNotification.Announcement(String(localized: status)).post()
        }
    }

    private var status: LocalizedStringResource {
        let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)
        return if consent == .allowed {
            LocalizedStringResource(
                "Usage data on. Thanks for helping.", bundle: bundle,
                comment: "Toast after the player allows usage data.")
        } else {
            LocalizedStringResource(
                "Usage data off.", bundle: bundle, comment: "Toast after the player declines usage data.")
        }
    }
}

#Preview("Prompt") {
    TrackdownFont.register()
    return TrackdownColor.background
        .ignoresSafeArea()
        .consentPrompt(isPresented: true) { _ in }
}

#Preview("Toast") {
    TrackdownFont.register()
    return TrackdownColor.background
        .ignoresSafeArea()
        .consentToast(.constant(.allowed)) {}
}
