import Analytics
import DesignSystem
import SwiftUI

extension View {
    /// Asks once whether the app may share anonymous usage data: a sheet as tall as its content that only an answer
    /// closes. Present it while the choice is unanswered; `onChoose` gets `.allowed` or `.declined`.
    public func consentPrompt(isPresented: Bool, onChoose: @escaping (AnalyticsConsent) -> Void) -> some View {
        // An answer changes `isPresented`; nothing else dismisses the sheet, so the binding never writes back.
        sheet(isPresented: .constant(isPresented)) {
            ConsentPrompt(onChoose: onChoose)
        }
    }

    /// Confirms the answer to the consent prompt in a glass toast above the guess bar, with a link to Privacy
    /// settings. The toast clears `consent` after a few seconds.
    public func consentToast(_ consent: Binding<AnalyticsConsent?>, onSettings: @escaping () -> Void) -> some View {
        overlay(alignment: .bottom) {
            if let choice = consent.wrappedValue {
                ConsentToast(consent: choice, onSettings: onSettings)
                    .padding(.horizontal, 16)
                    // Clears the guess bar, as on the design canvas.
                    .padding(.bottom, 72)
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
        .animation(.smooth, value: consent.wrappedValue)
    }
}

/// The first-launch question: the mark, why the app asks, the privacy policy, and Allow or Don't allow.
struct ConsentPrompt: View {
    let onChoose: (AnalyticsConsent) -> Void

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
                .font(TrackdownFont.title)
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
                }
                .buttonStyle(.plain)
                .padding(.vertical, -6)
                choices
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            // The sheet adds the bottom safe area below this.
            .padding(.bottom, 4)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                height = $0
            }
        }
        .scrollBounceBehavior(.basedOnSize)
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
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
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
