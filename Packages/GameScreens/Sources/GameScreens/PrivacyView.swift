import Analytics
import DesignSystem
import SwiftUI

#if os(iOS)
    import SafariServices
#endif

/// Usage data preferences. Push onto a navigation stack for the system glass back button.
public struct PrivacyView: View {
    @Bindable private var settings: AnalyticsSettings
    private let onClose: (() -> Void)?
    @State private var document: PrivacyDocument?
    @Environment(\.locale) private var locale

    /// - Parameters:
    ///   - settings: The usage data choice to show and change.
    ///   - onClose: Dismisses the sheet the screen is in, from a close button in its navigation bar. Leave it out on
    ///     the main navigation stack.
    public init(settings: AnalyticsSettings, onClose: (() -> Void)? = nil) {
        self.settings = settings
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy", bundle: .module, comment: "Title of the privacy settings screen.")
                    .font(TrackdownFont.largeTitle)
                    .foregroundStyle(TrackdownColor.ink)
                    .accessibilityAddTraits(.isHeader)
                usageData
                PrivacyExplanation()
                legalLinks
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .readableWidth()
        }
        .trackdownScrollEdges()
        .background { TrackdownColor.background.ignoresSafeArea() }
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .trailingBar) {
                    Button(action: onClose) {
                        TrackdownIcon.close.label
                    }
                }
            }
        }
        #if os(iOS)
            .sheet(item: $document) { document in
                PrivacySafariView(url: document.url(for: locale))
                .ignoresSafeArea()
            }
        #endif
    }

    private var usageData: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $settings.sharesUsageData) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share usage data", bundle: .module, comment: "Label of the analytics consent toggle.")
                        .font(TrackdownFont.title3)
                        .foregroundStyle(TrackdownColor.ink)
                    Text("Anonymous, through PostHog", bundle: .module, comment: "Subtitle of the analytics toggle.")
                        .font(TrackdownFont.callout)
                        .foregroundStyle(TrackdownColor.muted)
                }
            }
            .toggleStyle(.switch)
            .tint(TrackdownColor.line1)
            .padding(20)
            .background { ConcentricRectangle(corners: .concentric(minimum: .fixed(26))).fill(TrackdownColor.surface) }
            Group {
                if settings.sharesUsageData {
                    Text(
                        "On. Thanks for helping improve Trackdown.", bundle: .module,
                        comment: "Status under the analytics toggle when enabled.")
                } else {
                    Text(
                        "Off. You can turn this on or off at any time.", bundle: .module,
                        comment: "Status under the analytics toggle when disabled.")
                }
            }
            .font(TrackdownFont.callout)
            .foregroundStyle(TrackdownColor.muted)
            .padding(.horizontal, 20)
        }
    }

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                document = .privacyPolicy
            } label: {
                Text("Privacy policy", bundle: .module, comment: "Opens the Trackdown privacy policy in Safari.")
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            Button {
                document = .termsOfUse
            } label: {
                Text("Terms of use", bundle: .module, comment: "Opens the Trackdown terms in Safari.")
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
        .font(TrackdownFont.calloutEmphasized)
        .foregroundStyle(TrackdownColor.line1)
        .padding(.horizontal, 20)
    }
}

private struct PrivacyExplanation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why ask?", bundle: .module, comment: "Heading of the explanation of usage data.")
                .font(TrackdownFont.title3)
                .foregroundStyle(TrackdownColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Trackdown is a hobby project without ads. Anonymous usage data helps me understand how people play and where they get stuck, so I can improve the game. Nothing is sold. If you turn this off, the game works exactly the same.",
                bundle: .module, comment: "Explains why the player is asked to share anonymous usage data."
            )
            .font(TrackdownFont.body)
            .foregroundStyle(TrackdownColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background { ConcentricRectangle(corners: .concentric(minimum: .fixed(26))).fill(TrackdownColor.surface) }
    }
}

/// A legal page on trackdown.nl, in the player's language.
enum PrivacyDocument: String, Identifiable {
    case privacyPolicy
    case termsOfUse

    var id: Self { self }

    func url(for locale: Locale) -> URL {
        let prefix = locale.language.languageCode?.identifier == "nl" ? "" : "/en"
        switch self {
        case .privacyPolicy: return URL(string: "https://trackdown.nl\(prefix)/privacy")!
        case .termsOfUse: return URL(string: "https://trackdown.nl\(prefix)/voorwaarden")!
        }
    }
}

#if os(iOS)
    struct PrivacySafariView: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context: Context) -> SFSafariViewController {
            SFSafariViewController(url: url)
        }

        func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
    }
#endif
