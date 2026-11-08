import Observation

/// App-wide state, injected into the view tree through the environment.
@Observable
final class AppModel {
    let configuration: AppConfiguration

    init(configuration: AppConfiguration) {
        self.configuration = configuration
    }
}
