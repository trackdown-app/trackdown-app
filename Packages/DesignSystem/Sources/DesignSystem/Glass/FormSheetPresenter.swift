#if os(iOS)
    import SwiftUI
    import UIKit

    /// Presents `content` for `item` as a UIKit form sheet.
    ///
    /// SwiftUI's `sheet` keeps an iPhone's bottom sheet even where the horizontal size class is regular, such as on the
    /// iPhone Duo inner display, and ignores `presentationSizing(.form)` there. A UIKit form sheet is centred on a wide
    /// display, where the system also moves it clear of an active fold, and turns into a bottom sheet at `detents` on a
    /// narrow one. It is the same presentation either way, so opening or closing iPhone Duo keeps the sheet up with its
    /// state.
    struct FormSheetPresenter<Item: Identifiable, Content: View>: UIViewControllerRepresentable {
        @Binding var item: Item?
        let detents: (Item) -> Set<GlassSheetDetent>
        let content: (Item) -> Content

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeUIViewController(context: Context) -> FormSheetPresentingController {
            FormSheetPresentingController()
        }

        func updateUIViewController(_ controller: FormSheetPresentingController, context: Context) {
            let coordinator = context.coordinator
            let binding = $item
            coordinator.clearItem = { binding.wrappedValue = nil }
            guard let item else {
                coordinator.dismiss(from: controller)
                return
            }
            // Detents make even a form sheet a bottom sheet, so a wide display gets none.
            let detents = context.environment.horizontalSizeClass == .regular ? [.large] : detents(item)
            let id = AnyHashable(item.id)
            if let sheet = coordinator.sheet, coordinator.id == id {
                sheet.rootView = content(item)
                sheet.apply(detents)
                return
            }
            // Another item: its sheet replaces the one up.
            coordinator.dismiss(from: controller)
            let sheet = FormSheetController(rootView: content(item))
            sheet.apply(detents)
            sheet.onDismiss = { [weak coordinator, weak sheet] in
                // A sheet the item already moved on from must not clear its successor.
                guard let coordinator, let sheet, coordinator.sheet === sheet else { return }
                coordinator.sheet = nil
                coordinator.id = nil
                coordinator.clearItem()
            }
            coordinator.sheet = sheet
            coordinator.id = id
            controller.present(sheet)
        }

        static func dismantleUIViewController(_ controller: FormSheetPresentingController, coordinator: Coordinator) {
            coordinator.dismiss(from: controller)
        }

        @MainActor
        final class Coordinator {
            var sheet: FormSheetController<Content>?
            var id: AnyHashable?
            var clearItem: () -> Void = {}

            /// Takes down the sheet up, without clearing the item: the item already changed.
            func dismiss(from controller: FormSheetPresentingController) {
                guard let sheet else { return }
                self.sheet = nil
                id = nil
                controller.cancel(sheet)
                guard !sheet.isBeingDismissed else { return }
                // From its presenter, so a sheet it presented itself, such as Safari, goes too.
                sheet.presentingViewController?.dismiss(animated: true)
            }
        }
    }

    /// Where a form sheet is presented from: the top of the window's presentations, once this view is in a window.
    final class FormSheetPresentingController: UIViewController {
        private var pending: UIViewController?

        func present(_ sheet: UIViewController) {
            pending = sheet
            presentPending()
        }

        func cancel(_ sheet: UIViewController) {
            if pending === sheet { pending = nil }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            presentPending()
        }

        private func presentPending() {
            guard let sheet = pending, var top = viewIfLoaded?.window?.rootViewController else { return }
            while let presented = top.presentedViewController {
                if presented.isBeingDismissed {
                    // Wait for a sheet on its way out, such as the previous item's.
                    if let transition = presented.transitionCoordinator {
                        transition.animate(alongsideTransition: nil) { [weak self] _ in self?.presentPending() }
                    } else {
                        DispatchQueue.main.async { [weak self] in self?.presentPending() }
                    }
                    return
                }
                top = presented
            }
            pending = nil
            top.present(sheet, animated: true)
        }
    }

    /// The hosted sheet content, presented as a form sheet with the system's sheet background.
    final class FormSheetController<Content: View>: UIHostingController<Content> {
        /// The width of the form sheet on a wide display, as on the design canvas, and the most height it takes.
        private static var formSize: CGSize { CGSize(width: 540, height: 620) }

        /// Called once the sheet is gone, whatever took it down.
        var onDismiss: () -> Void = {}

        override init(rootView: Content) {
            super.init(rootView: rootView)
            modalPresentationStyle = .formSheet
            preferredContentSize = Self.formSize
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            // The system sheet background shows through.
            view.backgroundColor = .clear
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            if isBeingDismissed { onDismiss() }
        }

        /// The heights the sheet stops at as a bottom sheet, on a narrow display. Shortest first: it opens there.
        func apply(_ detents: Set<GlassSheetDetent>) {
            guard let sheet = sheetPresentationController else { return }
            let sorted = detents.sorted { $0.share < $1.share }
            // Only a sheet with somewhere to be dragged to shows the grabber.
            sheet.prefersGrabberVisible = sorted != [.large]
            // Setting the same detents again would move a sheet the player dragged back to the first.
            guard sheet.detents.map(\.identifier) != sorted.map(\.identifier) else { return }
            sheet.detents = sorted.map(\.sheetDetent)
        }
    }

    extension GlassSheetDetent {
        fileprivate var identifier: UISheetPresentationController.Detent.Identifier {
            switch self {
            case .medium: .medium
            case .large: .large
            case .fraction(let share): .init("fraction-\(share)")
            }
        }

        fileprivate var sheetDetent: UISheetPresentationController.Detent {
            switch self {
            case .medium: .medium()
            case .large: .large()
            case .fraction(let share):
                .custom(identifier: identifier) { context in context.maximumDetentValue * share }
            }
        }
    }
#endif
