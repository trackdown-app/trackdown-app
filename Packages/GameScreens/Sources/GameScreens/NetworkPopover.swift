import GameCore
import SwiftUI

/// The network picker as a popover from the network button, on a display wide enough to show it beside the puzzle, as
/// on the iPhone Duo inner display. A narrow display pushes ``ChooseNetworkView`` instead.
public struct NetworkPopover {
    let isPresented: Binding<Bool>
    let model: () -> ChooseNetworkModel
    let onChoose: (Network) -> Void
    let onNotify: (UpcomingNetwork) -> Void

    /// - Parameters:
    ///   - isPresented: Whether the popover shows. The network button's `onNavigate(.chooseNetwork)` should set it.
    ///   - model: Makes the networks to list, each time the popover opens.
    ///   - onChoose: Switches the game to the network. Close the popover too.
    ///   - onNotify: The player asked to hear when a network still to come comes out.
    public init(
        isPresented: Binding<Bool>,
        model: @escaping () -> ChooseNetworkModel,
        onChoose: @escaping (Network) -> Void,
        onNotify: @escaping (UpcomingNetwork) -> Void
    ) {
        self.isPresented = isPresented
        self.model = model
        self.onChoose = onChoose
        self.onNotify = onNotify
    }
}

extension View {
    /// Presents the network picker from this view, the network button, while `popover` asks for it. Without one, the
    /// button pushes the picker instead.
    func networkPopover(_ popover: NetworkPopover?) -> some View {
        // Always attached, so the button keeps its identity whether or not the display is wide enough.
        self.popover(isPresented: popover?.isPresented ?? .constant(false)) {
            if let popover {
                NetworkPopoverContent(popover: popover)
            } else {
                EmptyView()
            }
        }
    }
}

/// The popover's picker. Owns its model for as long as the popover is up.
private struct NetworkPopoverContent: View {
    @State private var model: ChooseNetworkModel
    private let onChoose: (Network) -> Void
    private let onNotify: (UpcomingNetwork) -> Void

    init(popover: NetworkPopover) {
        self.model = popover.model()
        self.onChoose = popover.onChoose
        self.onNotify = popover.onNotify
    }

    var body: some View {
        // The search field needs a navigation container to sit in.
        NavigationStack {
            ChooseNetworkView(model: model, onChoose: onChoose, onNotify: onNotify)
                // Nothing to go back to: the screen's own title heads the popover.
                .toolbarVisibility(.hidden, for: .topBar)
        }
        .frame(idealWidth: 400, idealHeight: 600)
    }
}
