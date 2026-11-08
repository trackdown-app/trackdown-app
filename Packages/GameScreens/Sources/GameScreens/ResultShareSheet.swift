#if os(iOS)
    import Analytics
    import SwiftUI
    import UIKit

    /// A snapshot of the result handed to the share sheet.
    struct ResultShare: Identifiable {
        let id = UUID()
        let text: String
    }

    /// ShareLink does not expose completion. UIKit distinguishes successful shares, copies and cancellation.
    struct ResultShareSheet: UIViewControllerRepresentable {
        let text: String
        let onComplete: @MainActor (AnalyticsEvent.ShareMethod, Bool, (any Error)?) -> Void

        func makeUIViewController(context: Context) -> UIActivityViewController {
            let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            controller.completionWithItemsHandler = { activity, completed, _, error in
                let method: AnalyticsEvent.ShareMethod = activity == .copyToPasteboard ? .copied : .shared
                Task { @MainActor in onComplete(method, completed, error) }
            }
            return controller
        }

        func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
    }
#endif
