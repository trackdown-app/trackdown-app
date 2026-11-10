import DesignSystem
import GameCore
import SwiftUI

/// The Statistics sheet: the player's record at one network, as the Solved and Missed sheet shows it.
///
/// Opened by the playing screen's statistics button. Present it in a
/// ``SwiftUI/View/glassSheet(item:detents:content:)``.
public struct StatisticsSheet: View {
    private let model: StatisticsModel

    /// - Parameter model: The network's record.
    public init(model: StatisticsModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassSheetHeader {
                    Text(
                        "Your \(model.networkName) record", bundle: .module,
                        comment:
                            "Title of the Statistics sheet. The argument is the rail network's name, such as Netherlands."
                    )
                }
                RecordView(statistics: model.statistics, bars: model.distribution) {
                    Task { await model.load() }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task { await model.load() }
    }
}
