import Analytics
import Foundation
import TrackdownAPI

/// Build-time settings read from Info.plist, which gets them from the xcconfig files in `Config/`.
struct AppConfiguration: Equatable {
    var api: APIConfiguration
    var analytics: AnalyticsConfiguration

    static func fromMainBundle() -> AppConfiguration {
        fromInfoDictionary(Bundle.main.infoDictionary ?? [:])
    }

    static func fromInfoDictionary(_ info: [String: Any]) -> AppConfiguration {
        let appVersion = info["CFBundleShortVersionString"] as? String ?? ""
        return AppConfiguration(
            api: APIConfiguration(
                baseURL: url(for: "TrackdownAPIBaseURL", in: info),
                clientKey: info["TrackdownClientKey"] as? String ?? "",
                appVersion: appVersion
            ),
            analytics: AnalyticsConfiguration(
                projectToken: info["PostHogProjectToken"] as? String ?? "",
                host: url(for: "PostHogHost", in: info),
                environment: analyticsEnvironment(in: info),
                appVersion: appVersion
            )
        )
    }

    private static func analyticsEnvironment(in info: [String: Any]) -> AnalyticsEnvironment {
        guard let value = info["PostHogEnvironment"] as? String,
            let environment = AnalyticsEnvironment(rawValue: value)
        else {
            preconditionFailure(
                "Info.plist key PostHogEnvironment must be development or production. Check Config/*.xcconfig."
            )
        }
        return environment
    }

    private static func url(for key: String, in info: [String: Any]) -> URL {
        guard let value = info[key] as? String, let url = URL(string: value), url.scheme != nil else {
            preconditionFailure("Info.plist key \(key) must be an absolute URL. Check Config/*.xcconfig.")
        }
        return url
    }
}
